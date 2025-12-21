import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import '../models/photo_settings.dart';
import '../models/background_type.dart';

/// Image processor that uses isolates for off-main-thread processing.
class ImageProcessor {
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

    // 3. Upscale to fill target
    // 'cover' logic: crop to fill
    return img.copyResize(
      lowRes,
      width: targetSize.width,
      height: targetSize.height,
      interpolation:
          img.Interpolation.linear, // Smooths out the upscaling pixels
    );
  }

  static int _calculateOptimalQuality(_ImageProcessingParams params) {
    if (params.isPreview) return 75;
    // For export, keep high quality but avoid 100 which is wasteful
    return params.settings.imageQuality.clamp(70, 95);
  }

  static void _overlayScaledImage(
    img.Image canvas,
    img.Image original,
    double scale,
    _Size targetSize,
  ) {
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

    // Center it
    final x = (targetSize.width - w) ~/ 2;
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
