import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/enums.dart';
import '../../models/panorama_geometry.dart';
import '../../models/panorama_settings.dart';

/// Widget-composited background + photo layer of the panorama canvas, with
/// no seam overlay. Reproduces `ImageProcessor`'s export maths in widgets
/// (GPU) rather than running `processPanorama` on every slider tick. See the
/// "UI" section of the panorama plan for the export ↔ widget correspondence
/// table this mirrors.
///
/// Split out from [PanoramaPreview] so the tile-count-aware seam grid can sit
/// on top for the in-editor preview, while the full-screen "preview like
/// Instagram" view can slice this same canvas into individual tiles with no
/// overlay at all, same compositing, two different frames around it.
class PanoramaCanvas extends StatelessWidget {
  final AssetEntity source;
  final PanoramaSettings settings;

  /// Needed (rather than measured off the rendered image) to size the exact
  /// contain-fit photo rect in Fit mode. See [_buildPhoto].
  final double sourceAspect;

  const PanoramaCanvas({
    super.key,
    required this.source,
    required this.settings,
    required this.sourceAspect,
  });

  @override
  Widget build(BuildContext context) {
    // Placement comes from the shared PanoramaGeometry rather than being
    // re-derived here, so the preview cannot drift from what the export
    // renders. It also carries the *clamped* offset: the photo can never be
    // painted past the canvas edge, which is what previously showed a chunk
    // of the photo missing behind a phantom background bar.
    final geometry = PanoramaGeometry.resolve(
      fitMode: settings.fitMode,
      tileCount: settings.tileCount,
      scale: settings.scale,
      cropOffsetX: settings.cropOffsetX,
      cropOffsetY: settings.cropOffsetY,
      sourceAspect: sourceAspect,
      canvasRatio: settings.canvasRatio,
    );

    return Stack(
      fit: StackFit.expand,
      children: [_buildBackground(), _buildPhoto(geometry)],
    );
  }

  Widget _buildPhoto(PanoramaGeometry geometry) {
    // Fill ↔ `_coverCropResize`: BoxFit.cover reproduces cover-then-crop with
    // no widget-side crop math needed, and `alignment` places the crop window
    //. The widget equivalent of the export's cropX. Alignment (rather than a
    // translate) is what keeps the photo covering the full canvas at every
    // offset; translating a cover-fitted image would expose an empty band at
    // one edge that the export never produces. No boundary line needed here:
    // the photo covers the whole canvas, so the canvas's own outer border
    // already marks its edge.
    if (settings.fitMode == PanoramaFitMode.fill) {
      // cropStart runs 0..cropSlack; Alignment.x runs -1..1 over that range.
      // Same mapping on Y, where the crop window is what the vertical nudge
      // moves, only one axis has any slack at a time (the cover fit consumes
      // the other exactly), so the unused one lands on 0.
      final cropSlackX = 1.0 - geometry.cropWidth;
      final alignmentX = cropSlackX <= 0
          ? 0.0
          : (2 * geometry.cropStart / cropSlackX - 1).clamp(-1.0, 1.0);

      final cropSlackY = 1.0 - geometry.cropHeight;
      final alignmentY = cropSlackY <= 0
          ? 0.0
          : (2 * geometry.cropTop / cropSlackY - 1).clamp(-1.0, 1.0);

      return AssetEntityImage(
        source,
        isOriginal: false,
        // 1920px thumbnail: comfortably above a typical device's rendered
        // preview width even stretched across a wide (e.g. 8:1) canvas,
        // without decoding the full-resolution source just for a preview.
        thumbnailSize: const ThumbnailSize(1920, 1920),
        fit: BoxFit.cover,
        alignment: Alignment(alignmentX, alignmentY),
      );
    }

    // Fit ↔ `_overlayScaledImage`: positioned explicitly from the geometry's
    // photo rect rather than left to BoxFit.contain plus a translate to work
    // out implicitly. An exact rect is what a corner-radius clip needs to hug
    // the photo's real edges rather than the canvas's own, and it applies the
    // nudge and its clamp in one step. Box aspect always comes out equal to
    // [sourceAspect] by construction, so BoxFit.fill inside it is lossless,
    // not a stretch.
    final heightFrac =
        settings.scale * math.min(1.0, settings.canvasRatio / sourceAspect);

    return LayoutBuilder(
      builder: (context, constraints) {
        final photoWidth =
            (geometry.photoEnd - geometry.photoStart) * constraints.maxWidth;
        final photoHeight = heightFrac * constraints.maxHeight;
        final radius =
            settings.cornerRadius * math.min(photoWidth, photoHeight);

        return Stack(
          children: [
            Positioned(
              left: geometry.photoStart * constraints.maxWidth,
              top: (constraints.maxHeight - photoHeight) / 2,
              width: photoWidth,
              height: photoHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: AssetEntityImage(
                  source,
                  isOriginal: false,
                  thumbnailSize: const ThumbnailSize(1920, 1920),
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackground() {
    if (settings.fitMode == PanoramaFitMode.fill) {
      // No bars in Fill. Background is fully covered by the photo.
      return const SizedBox.shrink();
    }

    // A picked photo color overrides backgroundType entirely. See
    // `plans/color_picking.md`.
    final customColor = settings.backgroundColor;
    if (customColor != null) {
      return Container(color: customColor);
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
