import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'image_size.dart';

class UserPreferences extends Equatable {
  final ThemeMode themeMode;
  final int imageQuality; // 1-100
  final ImageSizePreset imageSizePreset;
  final ImageSize customImageSize;

  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.imageQuality = 85,
    this.imageSizePreset = ImageSizePreset.instagramPortrait,
    this.customImageSize = const ImageSize(width: 1080, height: 1350),
  });

  @override
  List<Object?> get props => [
        themeMode,
        imageQuality,
        imageSizePreset,
        customImageSize,
      ];

  UserPreferences copyWith({
    ThemeMode? themeMode,
    int? imageQuality,
    ImageSizePreset? imageSizePreset,
    ImageSize? customImageSize,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      imageQuality: imageQuality ?? this.imageQuality,
      imageSizePreset: imageSizePreset ?? this.imageSizePreset,
      customImageSize: customImageSize ?? this.customImageSize,
    );
  }

  ImageSize get effectiveImageSize {
    if (imageSizePreset == ImageSizePreset.custom) {
      return customImageSize;
    }
    return imageSizePreset.size;
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'imageQuality': imageQuality,
      'imageSizePreset': imageSizePreset.index,
      'customImageSize': customImageSize.toJson(),
    };
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? 0],
      imageQuality: json['imageQuality'] as int? ?? 85,
      imageSizePreset: ImageSizePreset.values[json['imageSizePreset'] as int? ?? 0],
      customImageSize: json['customImageSize'] != null
          ? ImageSize.fromJson(json['customImageSize'] as Map<String, dynamic>)
          : const ImageSize(width: 1080, height: 1350),
    );
  }
}

