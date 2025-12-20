import 'package:equatable/equatable.dart';
import 'aspect_ratio.dart';
import 'background_type.dart';
import 'image_size.dart';

/// Photo processing settings for framing and export.
/// 
/// Contains all parameters needed to process a photo:
/// - Aspect ratio (scalable - 4:5, 1:1, 16:9, 9:16, etc.)
/// - Scale (0.5-1.0, where 1.0 fills the frame completely)
/// - Background type (white, black, or extended blur)
/// - Blur intensity (1-100, only used when background is extended blur)
/// - Image quality (1-100 JPEG quality)
/// - Target dimensions for export
class PhotoSettings extends Equatable {
  final AspectRatio aspectRatio;
  final double scale; // 0.5 to 1.0 (100% = fill completely)
  final BackgroundType backgroundType;
  final int blurIntensity; // 1-100 (blur radius, only for extendedBlur background)
  final int imageQuality; // 1-100 (JPEG quality)
  final ImageSize imageSize;

  const PhotoSettings({
    this.aspectRatio = AspectRatios.portrait,
    this.scale = 0.9,
    this.backgroundType = BackgroundType.white,
    this.blurIntensity = 25,
    this.imageQuality = 85,
    this.imageSize = const ImageSize(width: 1080, height: 1350),
  });

  @override
  List<Object?> get props => [
        aspectRatio,
        scale,
        backgroundType,
        blurIntensity,
        imageQuality,
        imageSize,
      ];

  PhotoSettings copyWith({
    AspectRatio? aspectRatio,
    double? scale,
    BackgroundType? backgroundType,
    int? blurIntensity,
    int? imageQuality,
    ImageSize? imageSize,
  }) {
    return PhotoSettings(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      scale: scale ?? this.scale,
      backgroundType: backgroundType ?? this.backgroundType,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      imageQuality: imageQuality ?? this.imageQuality,
      imageSize: imageSize ?? this.imageSize,
    );
  }
}

