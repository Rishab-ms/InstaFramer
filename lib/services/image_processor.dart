import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import 'package:palette_generator/palette_generator.dart' as pg;
import '../models/photo_settings.dart';
import '../models/enums.dart';
import '../models/panorama_settings.dart';

/// Image processor that uses isolates for off-main-thread processing.
class ImageProcessor {
  /// JPEG quality bounds applied to every export path. Below the floor,
  /// artefacts show on skies and gradients; above the ceiling, file size grows
  /// with no visible gain.
  static const int _minExportQuality = 70;
  static const int _maxExportQuality = 95;

  /// Previews are throwaway and never leave the device.
  static const int _previewQuality = 75;

  /// Weight given to the top and bottom rows of frame when scoring seam
  /// energy, relative to 1.0 at the middle row. See
  /// [_computeEdgeEnergyProfileInIsolate]. Low enough that a subject beats
  /// edge clutter, high enough that edge clutter still registers.
  static const double _edgeRowWeight = 0.35;

  static int _clampExportQuality(int quality) =>
      quality.clamp(_minExportQuality, _maxExportQuality);

  /// Process a single image with the given settings.
  ///
  /// accepts [imageBytes] directly to avoid double-loading data during export.
  Future<Uint8List> processImage(
    dynamic source, // AssetEntity or Uint8List
    PhotoSettings settings, {
    bool isExportProcessing = false,
  }) async {
    Uint8List bytes;

    if (source is Uint8List) {
      bytes = source;
    } else if (source is AssetEntity) {
      final originBytes = await source.originBytes;
      if (originBytes == null) throw Exception('Failed to load image bytes');
      bytes = originBytes;
    } else {
      throw Exception('Unsupported source type');
    }

    return await compute(
      _processImageInIsolate,
      _ImageProcessingParams(
        imageBytes: bytes,
        settings: settings,
        isPreview: false,
        isExportProcessing: isExportProcessing,
      ),
    );
  }

  /// Renders [sourceBytes] into an N x 0.8 canvas and slices it into
  /// `settings.tileCount` equal-width 4:5 tiles, in left-to-right order.
  ///
  /// One isolate call, not N: decode, blur background and cubic resize are
  /// canvas-global and account for over 90% of the cost, so slicing per tile
  /// would redo them N times and re-ship the full source bytes across the
  /// isolate boundary N times. `PanoramaSpec.maxTilesCap` is what bounds the
  /// canvas memory this holds.
  Future<List<Uint8List>> processPanorama(
    Uint8List sourceBytes,
    PanoramaSettings settings,
  ) {
    return compute(
      _processPanoramaInIsolate,
      _PanoramaProcessingParams(sourceBytes: sourceBytes, settings: settings),
    );
  }

  /// Per-column horizontal gradient energy of [thumbnailBytes], normalised to
  /// 0..1 and resampled to [samples] buckets spanning the full source width.
  ///
  /// ⚠️ **Not called.** This is the input to `PanoramaSeams`, which is kept
  /// but deliberately unwired. See the note on that class for why automatic
  /// positioning is off. Nothing computes this at pick time any more, which
  /// also spares every panorama an isolate round-trip it wasn't using.
  ///
  /// Columns with a strong vertical edge (a person, a pole, a building
  /// corner) score high; flat sky or water scores near zero. The seam
  /// offset that minimizes energy at every seam is one that avoids cutting
  /// through content. Rows near the vertical centre of frame count for more
  /// than rows at the top and bottom, since that is where subjects sit and
  /// where a cut is most conspicuous.
  ///
  /// Runs on a thumbnail, not `originBytes`: no full decode needed, and the
  /// profile only has to be directionally accurate, not pixel-precise.
  Future<List<double>> computeEdgeEnergyProfile(
    Uint8List thumbnailBytes, {
    int samples = 600,
  }) {
    return compute(
      _computeEdgeEnergyProfileInIsolate,
      _EdgeEnergyParams(thumbnailBytes: thumbnailBytes, samples: samples),
    );
  }

  static List<double> _computeEdgeEnergyProfileInIsolate(
    _EdgeEnergyParams params,
  ) {
    // 1. Decode the thumbnail (already small, no orientation-baking or
    // resizing needed, unlike the full export path).
    final image = img.decodeImage(params.thumbnailBytes);
    if (image == null) throw Exception('Failed to decode image');

    final width = image.width;
    final height = image.height;
    if (width < 3) return List<double>.filled(params.samples, 0);

    // 2. Weight each row by how close it is to the vertical centre, so the
    // score reflects what a seam cutting there would actually spoil.
    //
    // Summing rows evenly treats a power line across the sky, a fence along
    // the bottom edge, and a person's face as the same kind of obstacle. They
    // are not: subjects sit centre-frame, and clutter collects at the top and
    // bottom. Without this, a softly-lit face scores lower than the textured
    // grass beneath it and the seam happily cuts through the face.
    //
    // A raised cosine (peak 1.0 at the middle row) rather than a hard band, so
    // the weighting has no cliff a subject can straddle, lifted onto
    // [_edgeRowWeight] so the outermost rows still count for something. A
    // horizon cutting the very top of frame is a real seam hazard, just a
    // lesser one than a torso through the middle.
    final rowWeights = List<double>.generate(height, (y) {
      final t = height == 1 ? 0.5 : y / (height - 1);
      final centreness = 0.5 * (1 - math.cos(2 * math.pi * t));
      return _edgeRowWeight + (1 - _edgeRowWeight) * centreness;
    });

    // 3. Score every interior column by how much brightness changes
    // horizontally across it, accumulated down the column under those row
    // weights. A column that's part of a vertical edge (a pole, a torso, a
    // building corner) has large left-vs-right luminance jumps at many rows,
    // so it scores high; a column of flat sky or water scores near zero. This
    // is a one-dimensional Sobel-style horizontal gradient, one score per
    // column rather than per pixel.
    final rawEnergy = List<double>.filled(width, 0);
    for (var x = 1; x < width - 1; x++) {
      double sum = 0;
      for (var y = 0; y < height; y++) {
        final left = image.getPixel(x - 1, y).luminance;
        final right = image.getPixel(x + 1, y).luminance;
        sum += (right - left).abs() * rowWeights[y];
      }
      rawEnergy[x] = sum;
    }
    // Columns 0 and width-1 have no interior neighbour on one side; copy the
    // nearest computed column rather than leaving them at 0, which would
    // falsely look like a perfect seam spot.
    rawEnergy[0] = rawEnergy[1];
    rawEnergy[width - 1] = rawEnergy[width - 2];

    // 4. Normalise to 0..1 by dividing every column by the single highest
    // score in the image. This makes the profile comparable across photos
    // regardless of how busy or resolution each one is, `bestSeamOffset`
    // only cares about relative energy (higher = worse seam spot), not
    // absolute pixel-difference units.
    final maxEnergy = rawEnergy.fold<double>(0, (m, e) => e > m ? e : m);
    final normalized = maxEnergy == 0
        ? rawEnergy
        : rawEnergy.map((e) => e / maxEnergy).toList();

    // 5. Downsample from one score per source pixel-column (could be
    // thousands) to a fixed [samples] buckets spanning the same width. Each
    // output bucket is the average of every source column that falls inside
    // it, so this is a box-filter resize, not point sampling. A single
    // spike one pixel wide shouldn't vanish just because it landed between
    // two sample points. The fixed sample count keeps `bestSeamOffset`'s
    // search cost independent of the source photo's actual resolution.
    final resampled = List<double>.filled(params.samples, 0);
    for (var i = 0; i < params.samples; i++) {
      final startX = (i * width / params.samples).floor();
      final endX = (((i + 1) * width / params.samples).ceil()).clamp(
        startX + 1,
        width,
      );
      double sum = 0;
      for (var x = startX; x < endX; x++) {
        sum += normalized[x];
      }
      resampled[i] = sum / (endX - startX);
    }

    return resampled;
  }

  /// Up to 6 suggested background colors extracted from [thumbnailBytes],
  /// for offering alongside White/Black/Blur. See `plans/color_picking.md`.
  ///
  /// Runs on a thumbnail (same convention as [computeEdgeEnergyProfile]) and
  /// downscales further before quantizing. Dominant color doesn't need
  /// anywhere near full resolution, and this keeps the isolate call cheap
  /// regardless of source photo size.
  Future<List<Color>> extractPaletteColors(Uint8List thumbnailBytes) async {
    final argbValues = await compute(
      _extractPaletteColorsInIsolate,
      thumbnailBytes,
    );
    return argbValues.map(Color.new).toList();
  }

  /// Returns raw ARGB ints rather than [Color]. Safer to send across the
  /// isolate boundary than a `dart:ui` object graph, and the public method
  /// wraps them back into [Color] on the calling side.
  static Future<List<int>> _extractPaletteColorsInIsolate(
    Uint8List thumbnailBytes,
  ) async {
    final decoded = img.decodeImage(thumbnailBytes);
    if (decoded == null) return const [];

    // Downscale further still, same trick as the blur background generator.
    // Color quantization cares about the mix of hues present, not detail.
    final small = decoded.width >= decoded.height
        ? img.copyResize(decoded, width: math.min(200, decoded.width))
        : img.copyResize(decoded, height: math.min(200, decoded.height));

    final rgbaBytes = small.getBytes(order: img.ChannelOrder.rgba, alpha: 255);
    final palette = await pg.PaletteGenerator.fromByteData(
      pg.EncodedImage(
        ByteData.sublistView(rgbaBytes),
        width: small.width,
        height: small.height,
      ),
    );

    // Ordered by how "representative" each target is meant to be; the first
    // 6 unique colors are kept. Named targets (rather than the raw
    // population-sorted `paletteColors` list) give a spread across
    // light/dark/vibrant/muted instead of 6 near-duplicates from a single
    // busy region of the photo.
    final candidates = <pg.PaletteColor?>[
      palette.dominantColor,
      palette.vibrantColor,
      palette.darkVibrantColor,
      palette.lightVibrantColor,
      palette.mutedColor,
      palette.darkMutedColor,
      palette.lightMutedColor,
    ];

    final seen = <int>{};
    final result = <int>[];
    for (final candidate in candidates) {
      if (candidate == null) continue;
      final argb = candidate.color.toARGB32();
      if (seen.add(argb)) result.add(argb);
      if (result.length == 6) break;
    }
    return result;
  }

  static List<Uint8List> _processPanoramaInIsolate(
    _PanoramaProcessingParams params,
  ) {
    final settings = params.settings;

    // 1. Decode
    img.Image? source = img.decodeImage(params.sourceBytes);
    if (source == null) throw Exception('Failed to decode image');

    // 2. Bake EXIF rotation, guarded. BakeOrientation does an unconditional
    // full-image copy before checking whether there is anything to do, which is
    // tens of megabytes wasted on a large source.
    if (source.exif.imageIfd.hasOrientation &&
        source.exif.imageIfd.orientation != 1) {
      source = img.bakeOrientation(source);
    }

    final targetSize = _Size(settings.canvasWidth, settings.canvasHeight);

    // 3. Render the full canvas
    final img.Image canvas;
    switch (settings.fitMode) {
      case PanoramaFitMode.fill:
        canvas = _coverCropResize(
          source,
          targetSize.width,
          targetSize.height,
          // Negated: `_coverCropResize`'s offsetX moves the *crop window*,
          // while `cropOffsetX` is defined as moving the *photo* (see
          // PanoramaGeometry). Taking the crop from further left is what
          // slides the visible content right. Without this the seam slider
          // ran backwards in Fill relative to Fit.
          offsetX: -settings.cropOffsetXPx,
          // Negated for the same reason: `cropOffsetY` moves the photo down,
          // which means taking the crop from further up.
          offsetY: -settings.cropOffsetYPx,
          interpolation: img.Interpolation.cubic, // this is the photo itself
        );
      case PanoramaFitMode.fit:
        canvas = _createCanvasWithBackground(
          source,
          settings.backgroundType,
          targetSize,
          settings.blurIntensity,
          customColor: settings.backgroundColor,
        );
        _overlayScaledImage(
          canvas,
          source,
          settings.scale,
          targetSize,
          offsetX: settings.cropOffsetXPx,
          cornerRadiusFraction: settings.cornerRadius,
        );
    }

    // 4. Slice into tiles. canvasWidth is an exact multiple of tileWidth, so
    // the columns tile the canvas with zero overlap and zero gap.
    final quality = _clampExportQuality(settings.imageQuality);
    final tiles = <Uint8List>[];
    for (var i = 0; i < settings.tileCount; i++) {
      final tile = img.copyCrop(
        canvas,
        x: i * settings.tileWidth,
        y: 0,
        width: settings.tileWidth,
        height: settings.tileHeight,
      );
      tiles.add(Uint8List.fromList(img.encodeJpg(tile, quality: quality)));
    }

    return tiles;
  }

  static Uint8List _processImageInIsolate(_ImageProcessingParams params) {
    // 1. Decode image
    final originalImage = img.decodeImage(params.imageBytes);
    if (originalImage == null) throw Exception('Failed to decode image');

    // 2. Calculate dimensions
    final targetSize = params.isPreview
        ? _calculatePreviewSize(params.settings)
        : _calculateTargetSize(params.settings);

    // 3. Create canvas (Black/White or blurred)
    img.Image canvas = _createCanvasWithBackground(
      originalImage,
      params.settings.backgroundType,
      targetSize,
      params.settings.blurIntensity,
      // The framer has no photo-color picker yet. See
      // plans/color_picking.md's rollout order (panorama ships first).
      customColor: null,
    );

    // 4. Scale and center original photo
    _overlayScaledImage(
      canvas,
      originalImage,
      params.settings.scale,
      targetSize,
      offsetX: 0, // the framer has no seam concept
      cornerRadiusFraction: 0, // rounding is panorama-only for now
    );

    // 5. Encode
    final quality = _calculateOptimalQuality(params);
    final encoded = img.encodeJpg(canvas, quality: quality);

    return Uint8List.fromList(encoded);
  }

  static _Size _calculateTargetSize(PhotoSettings settings) {
    final baseWidth = settings.imageSize.width;
    final ratio = settings.aspectRatio.ratio;
    return _Size(baseWidth, (baseWidth / ratio).round());
  }

  static _Size _calculatePreviewSize(PhotoSettings settings) {
    const previewWidth = 600;
    final ratio = settings.aspectRatio.ratio;
    return _Size(previewWidth, (previewWidth / ratio).round());
  }

  static img.Image _createCanvasWithBackground(
    img.Image original,
    BackgroundType backgroundType,
    _Size targetSize,
    int blurIntensity, {
    required Color? customColor,
  }) {
    final canvas = img.Image(
      width: targetSize.width,
      height: targetSize.height,
    );

    // A picked photo color overrides backgroundType entirely. See
    // `plans/color_picking.md`. Checked first, ahead of the switch, so
    // white/black/blur never runs pointlessly underneath it.
    if (customColor != null) {
      final argb = customColor.toARGB32();
      return img.fill(
        canvas,
        color: img.ColorRgb8(
          (argb >> 16) & 0xff,
          (argb >> 8) & 0xff,
          argb & 0xff,
        ),
      );
    }

    switch (backgroundType) {
      case BackgroundType.white:
        return img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      case BackgroundType.black:
        return img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
      case BackgroundType.extendedBlur:
        // Generate blurred background
        final blurred = _generateFastBlurBackground(
          original,
          targetSize,
          blurIntensity,
        );
        // Fill canvas with it
        return img.compositeImage(canvas, blurred, center: true);
    }
  }

  /// Extremely optimized blur generation.
  ///
  /// Strategy:
  /// 1. Downscale source to tiny resolution (~300px).
  /// 2. Apply blur on tiny image (very fast).
  /// 3. Upscale back to target size.
  static img.Image _generateFastBlurBackground(
    img.Image original,
    _Size targetSize,
    int blurIntensity,
  ) {
    // 1. Aggressive Downsampling
    // Blurring detail away means we don't need high res source.
    // 300px is enough for a smooth background.
    const lowResWidth = 300;
    final lowResHeight = (lowResWidth / (original.width / original.height))
        .round();

    img.Image lowRes = img.copyResize(
      original,
      width: lowResWidth,
      height: lowResHeight,
      interpolation: img.Interpolation.linear, // Linear is fastest
    );

    // 2. Apply Blur
    // Scale sigma based on the size reduction to maintain visual intensity
    // Standard intensity 1-100 maps to reasonable sigma for 300px image
    final sigma = blurIntensity * 0.2;
    if (sigma > 0) {
      lowRes = img.gaussianBlur(lowRes, radius: sigma.toInt());
    }

    // 3. Cover the target: centre-crop to the target aspect, then upscale.
    // A plain resize here would stretch rather than cover. Imperceptible on a
    // 4:5 canvas, but a visible horizontal smear on a 3.2:1 panorama canvas.
    // The background stays centred while the photo slides, so both offsets
    // are 0.
    return _coverCropResize(
      lowRes,
      targetSize.width,
      targetSize.height,
      offsetX: 0,
      offsetY: 0,
      interpolation: img.Interpolation.linear, // source is already blurred
    );
  }

  /// Centre-crops [src] to the target aspect, then resizes to exactly
  /// [targetW]x[targetH]. 'Cover' semantics, no stretching.
  ///
  /// [offsetX] is a horizontal shift in **target** pixels; it is converted to
  /// source pixels and applied to the crop window. [interpolation] is the
  /// caller's quality/speed call. Cubic for the photo itself, linear for an
  /// already-blurred background where the extra taps buy nothing. Both are
  /// required rather than defaulted so every call site states its intent.
  static img.Image _coverCropResize(
    img.Image src,
    int targetW,
    int targetH, {
    required int offsetX,
    required int offsetY,
    required img.Interpolation interpolation,
  }) {
    final srcAspect = src.width / src.height;
    final dstAspect = targetW / targetH;

    final int cropW, cropH;
    if (srcAspect > dstAspect) {
      // Source is wider than the target → crop the sides
      cropH = src.height;
      cropW = (src.height * dstAspect).round();
    } else {
      // Source is taller than the target → crop top and bottom
      cropW = src.width;
      cropH = (src.width / dstAspect).round();
    }

    // Clamping matters: an unclamped window at an extreme offset would run past
    // the source edge and copyCrop would silently return a smaller image,
    // breaking the exact-multiple tiling.
    final scaledOffsetX = (offsetX * cropW / targetW).round();
    final cropX = ((src.width - cropW) ~/ 2 + scaledOffsetX).clamp(
      0,
      src.width - cropW,
    );

    final scaledOffsetY = (offsetY * cropH / targetH).round();
    final cropY = ((src.height - cropH) ~/ 2 + scaledOffsetY).clamp(
      0,
      src.height - cropH,
    );

    final cropped = img.copyCrop(
      src,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    return img.copyResize(
      cropped,
      width: targetW,
      height: targetH,
      interpolation: interpolation,
    );
  }

  static int _calculateOptimalQuality(_ImageProcessingParams params) {
    if (params.isPreview) return _previewQuality;
    return _clampExportQuality(params.settings.imageQuality);
  }

  /// Composites [original] contain-fitted and scaled onto [canvas].
  ///
  /// [offsetX] shifts the photo horizontally from centre, in canvas pixels.
  /// [cornerRadiusFraction] rounds the photo's own corners (as a fraction of
  /// its shorter side) before compositing, so the canvas background shows
  /// through, 0 for the plain framer, which has no rounding concept. Both
  /// are required rather than defaulted so every call site states its
  /// intent.
  static void _overlayScaledImage(
    img.Image canvas,
    img.Image original,
    double scale,
    _Size targetSize, {
    required int offsetX,
    required double cornerRadiusFraction,
  }) {
    // Calculate fit dimensions
    final originalAspect = original.width / original.height;
    final targetAspect = targetSize.width / targetSize.height;

    int w, h;

    if (originalAspect > targetAspect) {
      w = (targetSize.width * scale).round();
      h = (w / originalAspect).round();
    } else {
      h = (targetSize.height * scale).round();
      w = (h * originalAspect).round();
    }

    // Resize original (High quality for the actual photo)
    var resized = img.copyResize(
      original,
      width: w,
      height: h,
      interpolation: img.Interpolation.cubic, // Better quality for main image
    );

    if (cornerRadiusFraction > 0) {
      final radius = (cornerRadiusFraction * math.min(w, h)).round();
      // compositeImage's alpha blend reads this per-pixel, so the mask has
      // to live in an actual alpha channel. A JPEG-decoded source has none.
      resized = resized.convert(numChannels: 4);
      _applyRoundedCorners(resized, radius);
    }

    // Center it, then apply the horizontal nudge. Bounded by the slack
    // between the photo and the canvas edge. Fit mode's contract is that
    // nothing is cropped away, so the photo may slide within the bars but
    // never past them. The slack is zero (and the nudge correctly a no-op)
    // only when the scaled photo spans the full canvas width; on a panorama
    // canvas, which is usually far wider-aspect than the source, there is
    // real slack even at scale 1.0.
    final slack = (targetSize.width - w) ~/ 2;
    final x = slack + offsetX.clamp(-slack, slack);
    final y = (targetSize.height - h) ~/ 2;

    img.compositeImage(canvas, resized, dstX: x, dstY: y);
  }

  /// Zeroes alpha outside a [radius]-px quarter-circle in each corner of
  /// [image], in place. Only touches the four `radius x radius` corner
  /// boxes, not the whole image. Cheap even at high export resolution.
  ///
  /// A ~1px analytic band around the arc (the `+ 0.5` / `.clamp` below)
  /// antialiases the edge; a hard binary cut visibly jags at typical tile
  /// resolutions.
  static void _applyRoundedCorners(img.Image image, int radius) {
    if (radius <= 0) return;
    final maxAlpha = image.maxChannelValue;
    final w = image.width;
    final h = image.height;

    final corners = [
      (cx: radius, cy: radius, xs: 0, xe: radius, ys: 0, ye: radius),
      (cx: w - radius, cy: radius, xs: w - radius, xe: w, ys: 0, ye: radius),
      (cx: radius, cy: h - radius, xs: 0, xe: radius, ys: h - radius, ye: h),
      (
        cx: w - radius,
        cy: h - radius,
        xs: w - radius,
        xe: w,
        ys: h - radius,
        ye: h,
      ),
    ];

    for (final corner in corners) {
      for (var y = corner.ys; y < corner.ye; y++) {
        for (var x = corner.xs; x < corner.xe; x++) {
          final dx = x - corner.cx + 0.5;
          final dy = y - corner.cy + 0.5;
          final dist = math.sqrt(dx * dx + dy * dy);
          final coverage = (radius - dist + 0.5).clamp(0.0, 1.0);
          if (coverage >= 1) continue;
          final p = image.getPixel(x, y);
          image.setPixelRgba(x, y, p.r, p.g, p.b, coverage * maxAlpha);
        }
      }
    }
  }
}

class _Size {
  final int width, height;
  _Size(this.width, this.height);
}

class _ImageProcessingParams {
  final Uint8List imageBytes;
  final PhotoSettings settings;
  final bool isPreview;
  final bool isExportProcessing;

  _ImageProcessingParams({
    required this.imageBytes,
    required this.settings,
    required this.isPreview,
    required this.isExportProcessing,
  });
}

class _PanoramaProcessingParams {
  final Uint8List sourceBytes;
  final PanoramaSettings settings;

  _PanoramaProcessingParams({
    required this.sourceBytes,
    required this.settings,
  });
}

class _EdgeEnergyParams {
  final Uint8List thumbnailBytes;
  final int samples;

  _EdgeEnergyParams({required this.thumbnailBytes, required this.samples});
}
