import 'package:equatable/equatable.dart';
import 'aspect_ratio.dart';
import 'background_type.dart';
import 'image_size.dart';

class PhotoSettings extends Equatable {
  final AspectRatioType aspectRatio;
  final double scale; // 0.0 to 1.0 (100% = fill completely)
  final BackgroundType backgroundType;
  final int imageQuality; // 1-100 (JPEG quality)
  final ImageSize imageSize;

  const PhotoSettings({
    this.aspectRatio = AspectRatioType.portrait,
    this.scale = 0.9,
    this.backgroundType = BackgroundType.white,
    this.imageQuality = 85,
    this.imageSize = const ImageSize(width: 1080, height: 1350),
  });

  @override
  List<Object?> get props => [
        aspectRatio,
        scale,
        backgroundType,
        imageQuality,
        imageSize,
      ];

  PhotoSettings copyWith({
    AspectRatioType? aspectRatio,
    double? scale,
    BackgroundType? backgroundType,
    int? imageQuality,
    ImageSize? imageSize,
  }) {
    return PhotoSettings(
      aspectRatio: aspectRatio ?? this.aspectRatio,
      scale: scale ?? this.scale,
      backgroundType: backgroundType ?? this.backgroundType,
      imageQuality: imageQuality ?? this.imageQuality,
      imageSize: imageSize ?? this.imageSize,
    );
  }
}

