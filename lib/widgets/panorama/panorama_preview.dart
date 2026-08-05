import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/enums.dart';
import '../../models/panorama_settings.dart';
import 'panorama_seam_overlay.dart';

/// Widget-composited panorama preview — reproduces `ImageProcessor`'s export
/// maths in widgets (GPU) rather than running `processPanorama` on every
/// slider tick, which would regress preview performance on the widest canvas
/// in the app. See the "UI" section of the panorama plan for the export ↔
/// widget correspondence table this mirrors.
class PanoramaPreview extends StatelessWidget {
  final AssetEntity source;
  final PanoramaSettings settings;

  const PanoramaPreview({
    super.key,
    required this.source,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: settings.canvasRatio,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // seamOffset is in tile widths; as a fraction of the whole
            // canvas that's seamOffset / tileCount (canvasWidth = tileWidth
            // * tileCount), which converts directly to rendered pixels.
            final translateX =
                settings.seamOffset / settings.tileCount * constraints.maxWidth;

            return Stack(
              fit: StackFit.expand,
              children: [
                _buildBackground(),
                Transform.translate(
                  offset: Offset(translateX, 0),
                  child: _buildPhoto(),
                ),
                PanoramaSeamOverlay(tileCount: settings.tileCount),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoto() {
    if (settings.fitMode == PanoramaFitMode.fill) {
      return AssetEntityImage(
        source,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(1920, 1920),
        fit: BoxFit.cover,
      );
    }

    return Center(
      child: Transform.scale(
        scale: settings.scale,
        child: AssetEntityImage(
          source,
          isOriginal: false,
          thumbnailSize: const ThumbnailSize(1920, 1920),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (settings.fitMode == PanoramaFitMode.fill) {
      // No bars in Fill — background is fully covered by the photo.
      return const SizedBox.shrink();
    }

    switch (settings.backgroundType) {
      case BackgroundType.white:
        return Container(color: Colors.white);
      case BackgroundType.black:
        return Container(color: Colors.black);
      case BackgroundType.extendedBlur:
        return Stack(
          fit: StackFit.expand,
          children: [
            AssetEntityImage(
              source,
              isOriginal: false,
              thumbnailSize: const ThumbnailSize.square(150),
              fit: BoxFit.cover,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: settings.blurIntensity * 0.5,
                sigmaY: settings.blurIntensity * 0.5,
              ),
              child: Container(color: Colors.black.withOpacity(0.1)),
            ),
          ],
        );
    }
  }
}
