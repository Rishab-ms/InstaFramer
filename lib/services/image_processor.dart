import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import '../models/photo_settings.dart';
import '../models/aspect_ratio.dart';
import '../models/background_type.dart';

/// Image processor that uses isolates for off-main-thread processing.
/// 
/// All heavy image operations (decoding, resizing, blurring, encoding) run
/// in background isolates to keep the UI smooth and responsive.
class ImageProcessor {
  /// Process a single image with the given settings (full resolution for export).
  /// 
  /// Runs in a background isolate to avoid blocking the main thread.
  Future<Uint8List> processImage(
    AssetEntity asset,
    PhotoSettings settings,
  ) async {
    // Load image bytes on main thread (required for photo_manager API)
    final originalBytes = await asset.originBytes;
    if (originalBytes == null) {
      throw Exception('Failed to load image bytes');
    }

    // Offload heavy processing to isolate
    return await compute(
      _processImageInIsolate,
      _ImageProcessingParams(
        imageBytes: originalBytes,
        settings: settings,
        isPreview: false,
      ),
    );
  }

  /// Process a preview image with reduced resolution for better performance.
  /// 
  /// Runs in a background isolate and uses thumbnails for faster processing.
  /// Preview resolution is 800x800 max, processed at 600px width target.
  Future<Uint8List> processPreview(
    AssetEntity asset,
    PhotoSettings settings,
  ) async {
    // Load thumbnail instead of full resolution (much faster!)
    final thumbnailBytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize(800, 800),
      quality: 85,
    );
    if (thumbnailBytes == null) {
      throw Exception('Failed to load image thumbnail');
    }

    // Offload heavy processing to isolate
    return await compute(
      _processImageInIsolate,
      _ImageProcessingParams(
        imageBytes: thumbnailBytes,
        settings: settings,
        isPreview: true,
      ),
    );
  }

  /// Static method that runs in isolate - processes the image.
  /// 
  /// This function must be static or top-level to work with compute().
  /// All heavy operations happen here, off the main thread.
  static Uint8List _processImageInIsolate(_ImageProcessingParams params) {
    // 1. Decode image
    final originalImage = img.decodeImage(params.imageBytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // 2. Calculate target dimensions
    final targetSize = params.isPreview
        ? _calculatePreviewSize(params.settings)
        : _calculateTargetSize(params.settings);

    // 3. Create canvas with target size
    img.Image canvas = img.Image(
      width: targetSize.width,
      height: targetSize.height,
    );

    // 4. Apply background
    canvas = _applyBackground(
      canvas,
      originalImage,
      params.settings.backgroundType,
      targetSize,
      params.settings.blurIntensity,
    );

    // 5. Scale and center original photo
    canvas = _overlayScaledImage(
      canvas,
      originalImage,
      params.settings.scale,
      targetSize,
    );

    // 6. Encode to JPEG
    final quality = params.isPreview ? 75 : params.settings.imageQuality;
    final encoded = img.encodeJpg(canvas, quality: quality);

    return Uint8List.fromList(encoded);
  }

  static _Size _calculateTargetSize(PhotoSettings settings) {
    final baseWidth = settings.imageSize.width;
    final baseHeight = settings.imageSize.height;

    // Adjust based on aspect ratio
    if (settings.aspectRatio == AspectRatioType.portrait) {
      // 4:5 ratio
      final height = (baseWidth / 4 * 5).round();
      return _Size(baseWidth, height);
    } else {
      // 1:1 ratio (square)
      final size = baseWidth < baseHeight ? baseWidth : baseHeight;
      return _Size(size, size);
    }
  }

  /// Calculate preview dimensions (lower resolution for performance).
  static _Size _calculatePreviewSize(PhotoSettings settings) {
    // Use fixed preview width for consistent performance
    const previewWidth = 600;
    
    // Calculate height based on aspect ratio
    if (settings.aspectRatio == AspectRatioType.portrait) {
      // 4:5 ratio
      final height = (previewWidth / 4 * 5).round();
      return _Size(previewWidth, height);
    } else {
      // 1:1 ratio (square)
      return _Size(previewWidth, previewWidth);
    }
  }

  static img.Image _applyBackground(
    img.Image canvas,
    img.Image original,
    BackgroundType backgroundType,
    _Size targetSize,
    int blurIntensity,
  ) {
    switch (backgroundType) {
      case BackgroundType.white:
        img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
        return canvas;

      case BackgroundType.black:
        img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
        return canvas;

      case BackgroundType.extendedBlur:
        return _createBlurredBackground(canvas, original, targetSize, blurIntensity);
    }
  }

  static img.Image _createBlurredBackground(
    img.Image canvas,
    img.Image original,
    _Size targetSize,
    int blurIntensity,
  ) {
    // Resize original to fill canvas (will stretch/crop)
    final stretched = img.copyResize(
      original,
      width: targetSize.width,
      height: targetSize.height,
      interpolation: img.Interpolation.linear,
    );

    // Apply Gaussian blur with user-specified intensity
    final blurred = img.gaussianBlur(stretched, radius: blurIntensity);

    // Copy blurred image to canvas
    img.compositeImage(canvas, blurred);

    return canvas;
  }

  static img.Image _overlayScaledImage(
    img.Image canvas,
    img.Image original,
    double scale,
    _Size targetSize,
  ) {
    // Calculate scaled dimensions
    final originalAspect = original.width / original.height;
    final targetAspect = targetSize.width / targetSize.height;

    int scaledWidth;
    int scaledHeight;

    // Fit original image within target size while maintaining aspect ratio
    if (originalAspect > targetAspect) {
      // Original is wider
      scaledWidth = (targetSize.width * scale).round();
      scaledHeight = (scaledWidth / originalAspect).round();
    } else {
      // Original is taller or same
      scaledHeight = (targetSize.height * scale).round();
      scaledWidth = (scaledHeight * originalAspect).round();
    }

    // Ensure scaled image doesn't exceed canvas
    if (scaledWidth > targetSize.width) {
      scaledWidth = targetSize.width;
      scaledHeight = (scaledWidth / originalAspect).round();
    }
    if (scaledHeight > targetSize.height) {
      scaledHeight = targetSize.height;
      scaledWidth = (scaledHeight * originalAspect).round();
    }

    // Resize original to scaled dimensions
    final resized = img.copyResize(
      original,
      width: scaledWidth,
      height: scaledHeight,
      interpolation: img.Interpolation.average,
    );

    // Calculate center position
    final x = (targetSize.width - scaledWidth) ~/ 2;
    final y = (targetSize.height - scaledHeight) ~/ 2;

    // Overlay scaled image on canvas
    img.compositeImage(canvas, resized, dstX: x, dstY: y);

    return canvas;
  }
}

class _Size {
  final int width;
  final int height;

  _Size(this.width, this.height);
}

/// Parameters for image processing in isolate.
/// 
/// All data must be serializable to pass between isolates.
class _ImageProcessingParams {
  final Uint8List imageBytes;
  final PhotoSettings settings;
  final bool isPreview;

  _ImageProcessingParams({
    required this.imageBytes,
    required this.settings,
    required this.isPreview,
  });
}

