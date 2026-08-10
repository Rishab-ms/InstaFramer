import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dashed horizontal composition guides over the panorama canvas, shown while
/// the user is placing the photo vertically.
///
/// Takes the line positions as plain canvas-height fractions rather than a
/// style enum, so changing what the guides mean is a change at the call site
/// and nothing else: [thirds] today, [centre] if a single centre line turns
/// out to read better, or any other set without touching this widget. No
/// setting, no branch, no unused mode sitting in the codebase waiting.
///
/// Horizontal only, deliberately. Vertical guides would sit alongside
/// [PanoramaSeamOverlay]'s seam lines, which already divide the canvas
/// vertically and mean something quite different — two dashed vertical lines
/// with unrelated meanings on the same canvas is a worse picture, not a
/// richer one.
class PanoramaGuideOverlay extends StatelessWidget {
  /// Rule-of-thirds lines. Pairs with `PanoramaSpec.snapCropOffsetY`, which
  /// pulls toward the offsets that land the source's own thirds here — change
  /// one and the other stops meaning anything.
  static const List<double> thirds = [1 / 3, 2 / 3];

  /// A single centre line, for when thirds are more than the shot needs.
  static const List<double> centre = [0.5];

  /// Where to draw, as fractions of the canvas height (0 = top, 1 = bottom).
  final List<double> positions;

  /// Complements the actual background choice, same as the seam lines — see
  /// `PanoramaPreview._seamColor`.
  final Color color;

  const PanoramaGuideOverlay({
    super.key,
    required this.positions,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Purely to be seen — must never intercept a drag meant for the photo
    // beneath it, mirroring PanoramaSeamOverlay.
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _DashedGuidePainter(positions: positions, color: color),
      ),
    );
  }
}

/// Paints one short-dash horizontal line per position. Dash metrics match
/// `PanoramaSeamOverlay`'s vertical seam dashes so the two overlays read as
/// one drawing style rather than two.
class _DashedGuidePainter extends CustomPainter {
  static const _dashWidth = 4.0;
  static const _dashGap = 4.0;

  /// Inset from the canvas's left and right edges, so a guide never touches
  /// the border outline — the same 4px clearance the seam lines use.
  static const _edgeInset = 4.0;

  final List<double> positions;
  final Color color;

  const _DashedGuidePainter({required this.positions, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;

    for (final position in positions) {
      final y = position * size.height;
      var x = _edgeInset;
      while (x < size.width - _edgeInset) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + _dashWidth, size.width - _edgeInset), y),
          paint,
        );
        x += _dashWidth + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedGuidePainter oldDelegate) =>
      color != oldDelegate.color || positions != oldDelegate.positions;
}
