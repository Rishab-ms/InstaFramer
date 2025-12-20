import 'package:equatable/equatable.dart';

enum ImageSizePreset {
  instagramPortrait,
  instagramSquare,
  instagramLandscape,
  highQualityPortrait,
  highQualitySquare,
  custom,
}

extension ImageSizePresetExtension on ImageSizePreset {
  String get displayName {
    switch (this) {
      case ImageSizePreset.instagramPortrait:
        return 'Instagram Portrait - 1080×1350';
      case ImageSizePreset.instagramSquare:
        return 'Instagram Square - 1080×1080';
      case ImageSizePreset.instagramLandscape:
        return 'Instagram Landscape - 1080×566';
      case ImageSizePreset.highQualityPortrait:
        return 'High Quality Portrait - 1440×1800';
      case ImageSizePreset.highQualitySquare:
        return 'High Quality Square - 1440×1440';
      case ImageSizePreset.custom:
        return 'Custom Size';
    }
  }

  ImageSize get size {
    switch (this) {
      case ImageSizePreset.instagramPortrait:
        return const ImageSize(width: 1080, height: 1350);
      case ImageSizePreset.instagramSquare:
        return const ImageSize(width: 1080, height: 1080);
      case ImageSizePreset.instagramLandscape:
        return const ImageSize(width: 1080, height: 566);
      case ImageSizePreset.highQualityPortrait:
        return const ImageSize(width: 1440, height: 1800);
      case ImageSizePreset.highQualitySquare:
        return const ImageSize(width: 1440, height: 1440);
      case ImageSizePreset.custom:
        return const ImageSize(width: 1080, height: 1350); // Default
    }
  }
}

class ImageSize extends Equatable {
  final int width;
  final int height;

  const ImageSize({
    required this.width,
    required this.height,
  });

  @override
  List<Object?> get props => [width, height];

  ImageSize copyWith({
    int? width,
    int? height,
  }) {
    return ImageSize(
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
    };
  }

  factory ImageSize.fromJson(Map<String, dynamic> json) {
    return ImageSize(
      width: json['width'] as int,
      height: json['height'] as int,
    );
  }
}

