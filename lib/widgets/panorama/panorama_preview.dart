import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../models/enums.dart';
import '../../models/panorama_settings.dart';
import 'panorama_canvas.dart';
import 'panorama_guide_overlay.dart';
import 'panorama_seam_overlay.dart';

/// In-editor panorama preview: the composited [PanoramaCanvas] with the
/// seam grid drawn on top, sized to the full canvas aspect ratio. See the
/// "UI" section of the panorama plan for the export ↔ widget correspondence
/// table the canvas compositing mirrors.
class PanoramaPreview extends StatelessWidget {
  final AssetEntity source;
  final PanoramaSettings settings;
  final double sourceAspect;

  /// Composition guide lines to draw over the canvas, as canvas-height
  /// fractions — empty for none. The editor passes
  /// [PanoramaGuideOverlay.thirds] only while the user is actively dragging
  /// the vertical position: guides help while you are placing something and
  /// clutter the picture the rest of the time.
  final List<double> guidePositions;

  const PanoramaPreview({
    super.key,
    required this.source,
    required this.settings,
    required this.sourceAspect,
    this.guidePositions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: settings.canvasRatio,
      // Rounded corners so the dashed outline (painted below) has somewhere
      // to bend — clipped to match so a translated photo can't paint past
      // the canvas bounds either, mirroring `copyCrop` self-clamping the
      // export's canvas.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_PanoramaBorderPainter.radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Paint order matters: the canvas (background bars/blur +
            // photo) sits behind, and the seam overlay must be topmost so
            // its seam lines are always visible over both.
            PanoramaCanvas(
              source: source,
              settings: settings,
              sourceAspect: sourceAspect,
            ),
            PanoramaSeamOverlay(
              tileCount: settings.tileCount,
              seamColor: _seamColor(settings),
            ),
            if (guidePositions.isNotEmpty)
              PanoramaGuideOverlay(
                positions: guidePositions,
                color: _seamColor(settings),
              ),
            // A visible outline regardless of background choice — a white
            // background otherwise reads as "no canvas at all" against the
            // screen's own background, so the canvas edge needs its own
            // line rather than relying on a color contrast that only
            // sometimes exists. Drawn as the topmost Stack layer (not a
            // BoxDecoration) so it can never be painted over by the
            // background/photo content beneath it.
            const IgnorePointer(
              child: CustomPaint(
                size: Size.infinite,
                painter: _PanoramaBorderPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Picks a dashed-line color that complements the actual background
  /// choice, rather than boxing the seam in its own backdrop. Fill mode has
  /// no background bars — the photo covers the whole canvas — so there's no
  /// single background color to key off; white is the least-bad default
  /// there.
  Color _seamColor(PanoramaSettings settings) {
    if (settings.fitMode == PanoramaFitMode.fill) return Colors.white;

    final customColor = settings.backgroundColor;
    if (customColor != null) {
      // Same contrast logic as the white/black cases below, generalised for
      // an arbitrary picked color rather than the two fixed extremes.
      return ThemeData.estimateBrightnessForColor(customColor) ==
              Brightness.light
          ? Colors.black87
          : Colors.white;
    }

    switch (settings.backgroundType) {
      case BackgroundType.white:
        return Colors.black87;
      case BackgroundType.black:
        return Colors.white;
      case BackgroundType.extendedBlur:
        return Colors.white;
    }
  }
}

/// Dashed, rounded-rect canvas outline. A plain grey rather than a
/// theme-derived color — like the seam line, this needs to read consistently
/// against white/black/blur backgrounds, not shift with light/dark theme.
class _PanoramaBorderPainter extends CustomPainter {
  static const double radius = 4;
  static const double _dashLength = 6;
  static const double _gapLength = 4;

  const _PanoramaBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(radius),
    );
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final metrics = (Path()..addRRect(rrect)).computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + _gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PanoramaBorderPainter oldDelegate) => false;
}
