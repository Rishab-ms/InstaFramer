import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/background_type.dart';
import '../../services/image_processor.dart';

/// Individual photo card widget for the carousel.
///
/// OPTIMIZED VERSION: Uses Flutter Widgets for composition (GPU) instead of
/// pixel manipulation (CPU). This eliminates lag during preview.
class PhotoCard extends StatelessWidget {
  final int photoIndex;
  final AssetEntity photo;
  final dynamic settings; // PhotoSettings
  final int currentIndex;
  final ImageProcessor imageProcessor;

  const PhotoCard({
    super.key,
    required this.photoIndex,
    required this.photo,
    required this.settings,
    required this.currentIndex,
    required this.imageProcessor,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate aspect ratio double from the settings
    final double aspectRatio = settings.aspectRatio.ratio;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Background
            _buildBackground(context),

            // Layer 2: Foreground (The Photo)
            Center(
              child: Transform.scale(
                scale: settings.scale,
                child: AssetEntityImage(
                  photo,
                  isOriginal: false, // Use thumbnail for preview speed
                  thumbnailSize: const ThumbnailSize.square(800),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground(BuildContext context) {
    switch (settings.backgroundType) {
      case BackgroundType.white:
        return Container(color: Colors.white);

      case BackgroundType.black:
        return Container(color: Colors.black);

      case BackgroundType.extendedBlur:
        // OPTIMIZATION: Use a very small thumbnail for the blur background.
        // Blurring hides resolution artifacts, so we save massive memory/GPU
        // by scaling up a tiny image.
        return Stack(
          fit: StackFit.expand,
          children: [
            AssetEntityImage(
              photo,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(
                150,
              ), // Low res for blur
              fit: BoxFit.cover,
            ),
            // Apply Gaussian Blur on top using GPU
            BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX:
                    settings.blurIntensity *
                    0.5, // Adjust multiplier to match export feel
                sigmaY: settings.blurIntensity * 0.5,
              ),
              child: Container(
                color: Colors.black.withOpacity(0.1), // Slight dim for contrast
              ),
            ),
          ],
        );

      default:
        return Container(color: Colors.white);
    }
  }
}
