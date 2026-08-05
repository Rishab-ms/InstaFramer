import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual seam guides over the panorama canvas — a dashed "cut here" line
/// with a small scissor icon bookending each seam, plus a centred
/// tile-number badge per tile.
///
/// The dashed-line-and-scissors motif is a deliberate whimsical touch (this
/// widget could just as easily be a plain solid divider) — it leans into
/// "cut along the dotted line" as a metaphor for what a seam actually is:
/// the line Instagram's carousel will visually stitch back together, not a
/// debug ruler.
///
/// Pixel-accurate regardless of fit mode: the tiles are exact equal
/// fractions of the canvas, so this is an overlay, not derived from the
/// rendered image.
class PanoramaSeamOverlay extends StatelessWidget {
  final int tileCount;

  const PanoramaSeamOverlay({super.key, required this.tileCount});

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
              // Tile-number badges, centred in each tile.
              Row(
                children: List.generate(tileCount, (i) {
                  return Expanded(
                    child: Center(child: _TileBadge(number: i + 1)),
                  );
                }),
              ),
              // Interior seams only — the canvas's own outer edge isn't a
              // seam Instagram will ever show stitched.
              for (var i = 1; i < tileCount; i++)
                Positioned(
                  // Centre the dashed line on the seam x-coordinate.
                  left: tileWidth * i - _DashedSeam.width / 2,
                  top: 0,
                  bottom: 0,
                  child: const _DashedSeam(),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One dashed vertical seam line with a small scissor icon at each end.
class _DashedSeam extends StatelessWidget {
  static const double width = 20;

  const _DashedSeam();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        children: [
          // Rotated to "point" down the seam, mirrored at the bottom so the
          // pair reads as bookends rather than two copies of the same icon.
          Transform.rotate(
            angle: math.pi / 2,
            child: const Icon(
              Icons.content_cut,
              size: 14,
              color: Colors.white70,
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, double.infinity),
              painter: _DashedLinePainter(),
            ),
          ),
          Transform.rotate(
            angle: -math.pi / 2,
            child: const Icon(
              Icons.content_cut,
              size: 14,
              color: Colors.white70,
            ),
          ),
        ],
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

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
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

  // Static dash pattern — never needs to repaint for different reasons than
  // the parent widget rebuilding, so there's no state to diff here.
  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) => false;
}

/// Small numbered badge identifying a tile, matching the numbering the
/// export success sheet (Step 3) will use to explain tap order.
class _TileBadge extends StatelessWidget {
  final int number;

  const _TileBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
