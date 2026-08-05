import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
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

  static List<Uint8List> _processPanoramaInIsolate(
    _PanoramaProcessingParams params,
  ) {
    final settings = params.settings;

    // 1. Decode
    img.Image? source = img.decodeImage(params.sourceBytes);
    if (source == null) throw Exception('Failed to decode image');

    // 2. Bake EXIF rotation, guarded — bakeOrientation does an unconditional
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
          offsetX: settings.seamOffsetPx,
          interpolation: img.Interpolation.cubic, // this is the photo itself
        );
      case PanoramaFitMode.fit:
        canvas = _createCanvasWithBackground(
          source,
          settings.backgroundType,
          targetSize,
          settings.blurIntensity,
        );
        _overlayScaledImage(
          canvas,
          source,
          settings.scale,
          targetSize,
          offsetX: settings.seamOffsetPx,
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
    );

    // 4. Scale and center original photo
    _overlayScaledImage(
      canvas,
      originalImage,
      params.settings.scale,
      targetSize,
      offsetX: 0, // the framer has no seam concept
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
    int blurIntensity,
  ) {
    final canvas = img.Image(
      width: targetSize.width,
      height: targetSize.height,
    );

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
    // A plain resize here would stretch rather than cover — imperceptible on a
    // 4:5 canvas, but a visible horizontal smear on a 3.2:1 panorama canvas.
    // The background stays centred while the photo slides, so offsetX is 0.
    return _coverCropResize(
      lowRes,
      targetSize.width,
      targetSize.height,
      offsetX: 0,
      interpolation: img.Interpolation.linear, // source is already blurred
    );
  }

  /// Centre-crops [src] to the target aspect, then resizes to exactly
  /// [targetW]x[targetH] — 'cover' semantics, no stretching.
  ///
  /// [offsetX] is a horizontal shift in **target** pixels; it is converted to
  /// source pixels and applied to the crop window. [interpolation] is the
  /// caller's quality/speed call — cubic for the photo itself, linear for an
  /// already-blurred background where the extra taps buy nothing. Both are
  /// required rather than defaulted so every call site states its intent.
  static img.Image _coverCropResize(
    img.Image src,
    int targetW,
    int targetH, {
    required int offsetX,
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
    final scaledOffset = (offsetX * cropW / targetW).round();
    final cropX = ((src.width - cropW) ~/ 2 + scaledOffset)
        .clamp(0, src.width - cropW);

    final cropped = img.copyCrop(
      src,
      x: cropX,
      y: (src.height - cropH) ~/ 2,
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
  /// Required rather than defaulted so every call site states its intent.
  static void _overlayScaledImage(
    img.Image canvas,
    img.Image original,
    double scale,
    _Size targetSize, {
    required int offsetX,
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
    final resized = img.copyResize(
      original,
      width: w,
      height: h,
      interpolation: img.Interpolation.cubic, // Better quality for main image
    );

    // Center it, then apply the horizontal nudge — bounded by the slack
    // between the photo and the canvas edge. Fit mode's contract is that
    // nothing is cropped away, so the photo may slide within the bars but
    // never past them; at scale 1.0 there is no slack and the nudge is
    // correctly a no-op.
    final slack = (targetSize.width - w) ~/ 2;
    final x = slack + offsetX.clamp(-slack, slack);
    final y = (targetSize.height - h) ~/ 2;

    img.compositeImage(canvas, resized, dstX: x, dstY: y);
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
