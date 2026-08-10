import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/enums.dart';
import '../../models/panorama_settings.dart';

/// Widget-composited background + photo layer of the panorama canvas, with
/// no seam overlay — reproduces `ImageProcessor`'s export maths in widgets
/// (GPU) rather than running `processPanorama` on every slider tick. See the
/// "UI" section of the panorama plan for the export ↔ widget correspondence
/// table this mirrors.
///
/// Split out from [PanoramaPreview] so the tile-count-aware seam grid can sit
/// on top for the in-editor preview, while the full-screen "preview like
/// Instagram" view can slice this same canvas into individual tiles with no
/// overlay at all — same compositing, two different frames around it.
class PanoramaCanvas extends StatelessWidget {
  final AssetEntity source;
  final PanoramaSettings settings;

  const PanoramaCanvas({
    super.key,
    required this.source,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // seamOffset is in tile widths (see PanoramaSettings); as a
        // fraction of the whole canvas that's seamOffset / tileCount
        // (canvasWidth = tileWidth * tileCount), which converts directly
        // to rendered pixels via constraints.maxWidth.
        final translateX =
            settings.seamOffset / settings.tileCount * constraints.maxWidth;

        // ⚠️ Known preview/export mismatch: `_overlayScaledImage` in
        // ImageProcessor clamps the export's offsetX to the slack
        // between the scaled photo and the canvas edge (zero slack at
        // scale 1.0, so the nudge is correctly a no-op there). This
        // widget applies translateX unconditionally, so at scale 1.0 the
        // *preview* can show the photo sliding past what the export will
        // actually produce. Needs the same slack-based clamp before this
        // preview can be trusted as pixel-honest at high scale values —
        // flagging rather than silently fixing since it changes visible
        // slider behavior.
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildBackground(),
            Transform.translate(
              offset: Offset(translateX, 0),
              child: _buildPhoto(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhoto() {
    // Fill ↔ `_coverCropResize`: BoxFit.cover reproduces cover-then-centre-
    // crop with no widget-side crop math needed — Flutter's cover fit and
    // the export's centre-crop-then-resize converge on the same visible
    // region.
    if (settings.fitMode == PanoramaFitMode.fill) {
      return AssetEntityImage(
        source,
        isOriginal: false,
        // 1920px thumbnail: comfortably above a typical device's rendered
        // preview width even stretched across a wide (e.g. 8:1) canvas,
        // without decoding the full-resolution source just for a preview.
        thumbnailSize: const ThumbnailSize(1920, 1920),
        fit: BoxFit.cover,
      );
    }

    // Fit ↔ `_overlayScaledImage`: Center + BoxFit.contain reproduces
    // contain-fit-and-centre; Transform.scale reproduces the scale slider.
    // Both operate on the same canvas-sized box, so the photo shrinks
    // in place exactly as `_overlayScaledImage` shrinks it before centring.
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
              child: Container(color: Colors.black.withValues(alpha: 0.1)),
            ),
          ],
        );
    }
  }
}
