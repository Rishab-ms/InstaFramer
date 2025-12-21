import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'image_size.dart';

/// User preferences persisted across app sessions.
///
/// Contains app-wide settings and last-used editor values:
/// - Theme mode (system/light/dark)
/// - Export quality and size settings
/// - Last used scale (remembered for next session)
/// - Last used blur intensity (remembered for next session)
/// - Metadata preservation setting (preserve EXIF data like date/location)
class UserPreferences extends Equatable {
  final ThemeMode themeMode;
  final int imageQuality; // 1-100
  final ImageSizePreset imageSizePreset;
  final ImageSize customImageSize;
  final double lastUsedScale; // Remember last scale setting (0.5-1.0)
  final int lastUsedBlurIntensity; // Remember last blur intensity (1-100)
  final bool preserveMetadata; // Preserve EXIF metadata (date, location, etc.)

  const UserPreferences({
    this.themeMode = ThemeMode.system,
    this.imageQuality = 85,
    this.imageSizePreset = ImageSizePreset.instagramPortrait,
    this.customImageSize = const ImageSize(width: 1080, height: 1350),
    this.lastUsedScale = 0.92,
    this.lastUsedBlurIntensity = 75,
    this.preserveMetadata = true,
  });

  @override
  List<Object?> get props => [
        themeMode,
        imageQuality,
        imageSizePreset,
        customImageSize,
        lastUsedScale,
        lastUsedBlurIntensity,
        preserveMetadata,
      ];

  UserPreferences copyWith({
    ThemeMode? themeMode,
    int? imageQuality,
    ImageSizePreset? imageSizePreset,
    ImageSize? customImageSize,
    double? lastUsedScale,
    int? lastUsedBlurIntensity,
    bool? preserveMetadata,
  }) {
    return UserPreferences(
      themeMode: themeMode ?? this.themeMode,
      imageQuality: imageQuality ?? this.imageQuality,
      imageSizePreset: imageSizePreset ?? this.imageSizePreset,
      customImageSize: customImageSize ?? this.customImageSize,
      lastUsedScale: lastUsedScale ?? this.lastUsedScale,
      lastUsedBlurIntensity: lastUsedBlurIntensity ?? this.lastUsedBlurIntensity,
      preserveMetadata: preserveMetadata ?? this.preserveMetadata,
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
      'lastUsedScale': lastUsedScale,
      'lastUsedBlurIntensity': lastUsedBlurIntensity,
      'preserveMetadata': preserveMetadata,
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
      lastUsedScale: (json['lastUsedScale'] as num?)?.toDouble() ?? 0.92,
      lastUsedBlurIntensity: json['lastUsedBlurIntensity'] as int? ?? 75,
      preserveMetadata: json['preserveMetadata'] as bool? ?? true,
    );
  }
}

