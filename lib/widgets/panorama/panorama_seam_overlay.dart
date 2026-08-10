import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual seam guides over the panorama canvas — a dashed "cut here" line
/// at each interior tile boundary.
///
/// Pixel-accurate regardless of fit mode: the tiles are exact equal
/// fractions of the canvas, so this is an overlay, not derived from the
/// rendered image.
class PanoramaSeamOverlay extends StatelessWidget {
  final int tileCount;

  /// Complements the actual background choice (white/black/blur) so the
  /// seam is legible without needing its own backdrop — see
  /// `PanoramaPreview._seamColor`.
  final Color seamColor;

  const PanoramaSeamOverlay({
    super.key,
    required this.tileCount,
    required this.seamColor,
  });

  @override
  Widget build(BuildContext context) {
    // This overlay sits on top of the photo in the preview Stack purely to
    // be seen — it must not intercept taps/drags meant for whatever's
    // beneath it (e.g. a future pan/zoom gesture on the photo).
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Equal-width tiles are the point: they mirror the export's
          // exact-multiple tiling (`canvasWidth = tileWidth * tileCount`),
          // so a seam drawn here always lines up with the real cut column
          // regardless of screen size.
          final tileWidth = constraints.maxWidth / tileCount;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Interior seams only — the canvas's own outer edge isn't a
              // seam Instagram will ever show stitched.
              for (var i = 1; i < tileCount; i++)
                Positioned(
                  // Centre the seam's own width on the seam x-coordinate.
                  left: tileWidth * i - _DashedSeam.width / 2,
                  // 4px clear of the canvas's own border so the dashed
                  // line doesn't touch it, most visible at scale 1.0 where
                  // the photo fills the canvas edge-to-edge.
                  top: 4,
                  bottom: 4,
                  child: _DashedSeam(color: seamColor),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One dashed vertical seam line, tinted to complement the actual
/// background (see [PanoramaSeamOverlay]) — no backdrop of its own, just a
/// color chosen to read against what's underneath.
class _DashedSeam extends StatelessWidget {
  static const double width = 20;

  final Color color;

  const _DashedSeam({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: CustomPaint(
        size: Size.infinite,
        painter: _DashedLinePainter(color: color),
      ),
    );
  }
}

/// Paints a short-dash vertical line centred in its box. A `Border` can't
/// draw dashes, so this is the minimal amount of custom painting needed for
/// the "cut here" line — dash/gap sizes are cosmetic and safe to retune.
class _DashedLinePainter extends CustomPainter {
  static const _dashHeight = 4.0;
  static const _dashGap = 4.0;

  final Color color;

  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    final x = size.width / 2;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + _dashHeight, size.height)),
        paint,
      );
      y += _dashHeight + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}
