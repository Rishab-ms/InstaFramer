import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:image/image.dart' as img;
import '../models/photo_settings.dart';
import '../models/aspect_ratio.dart';
import '../models/background_type.dart';

class ImageProcessor {
  /// Process a single image with the given settings
  Future<Uint8List> processImage(
    AssetEntity asset,
    PhotoSettings settings,
  ) async {
    // 1. Load original image bytes
    final originalBytes = await asset.originBytes;
    if (originalBytes == null) {
      throw Exception('Failed to load image bytes');
    }

    // 2. Decode using image package
    final originalImage = img.decodeImage(originalBytes);
    if (originalImage == null) {
      throw Exception('Failed to decode image');
    }

    // 3. Calculate target dimensions based on aspect ratio and size settings
    final targetSize = _calculateTargetSize(settings);

    // 4. Create canvas with target size
    img.Image canvas = img.Image(
      width: targetSize.width,
      height: targetSize.height,
    );

    // 5. Apply background
    canvas = _applyBackground(
      canvas,
      originalImage,
      settings.backgroundType,
      targetSize,
    );

    // 6. Scale and center original photo
    canvas = _overlayScaledImage(
      canvas,
      originalImage,
      settings.scale,
      targetSize,
    );

    // 7. Encode to JPEG with quality setting
    final encoded = img.encodeJpg(canvas, quality: settings.imageQuality);

    return Uint8List.fromList(encoded);
  }

  _Size _calculateTargetSize(PhotoSettings settings) {
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

  img.Image _applyBackground(
    img.Image canvas,
    img.Image original,
    BackgroundType backgroundType,
    _Size targetSize,
  ) {
    switch (backgroundType) {
      case BackgroundType.white:
        img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
        return canvas;

      case BackgroundType.black:
        img.fill(canvas, color: img.ColorRgb8(0, 0, 0));
        return canvas;

      case BackgroundType.extendedBlur:
        return _createBlurredBackground(canvas, original, targetSize);
    }
  }

  img.Image _createBlurredBackground(
    img.Image canvas,
    img.Image original,
    _Size targetSize,
  ) {
    // Resize original to fill canvas (will stretch/crop)
    final stretched = img.copyResize(
      original,
      width: targetSize.width,
      height: targetSize.height,
      interpolation: img.Interpolation.linear,
    );

    // Apply Gaussian blur
    final blurred = img.gaussianBlur(stretched, radius: 25);

    // Copy blurred image to canvas
    img.compositeImage(canvas, blurred);

    return canvas;
  }

  img.Image _overlayScaledImage(
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

