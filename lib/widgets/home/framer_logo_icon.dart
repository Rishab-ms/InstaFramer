import 'package:flutter/material.dart';

/// InstaFramer's home-screen mark: four open, viewfinder-style corner
/// brackets — no connecting bars (which read as a cage/grid at small sizes,
/// as `LucideIcons.frame` did) and no photo glyph inside. Custom-painted
/// rather than pulled from an icon library on purpose: a brand mark is
/// supposed to be distinctive, the opposite of the app's small in-flow
/// icons, where matching a recognizable standard vocabulary (Lucide) is
/// what actually matters.
class FramerLogoIcon extends StatelessWidget {
  final double size;
  final Color color;

  const FramerLogoIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _FramerLogoPainter(color: color),
    );
  }
}

class _FramerLogoPainter extends CustomPainter {
  final Color color;

  const _FramerLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.shortestSide * 0.09;
    final armLength = size.shortestSide * 0.34;
    final bendRadius = strokeWidth * 1.1;
    final inset = strokeWidth / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect =
        Offset(inset, inset) & Size.square(size.shortestSide - strokeWidth);

    _drawCorner(canvas, paint, rect.topLeft, armLength, bendRadius, 1, 1);
    _drawCorner(canvas, paint, rect.topRight, armLength, bendRadius, -1, 1);
    _drawCorner(canvas, paint, rect.bottomLeft, armLength, bendRadius, 1, -1);
    _drawCorner(canvas, paint, rect.bottomRight, armLength, bendRadius, -1, -1);
  }

  /// One L-shaped bracket anchored at [corner], arms extending inward along
  /// each axis by [dx]/[dy]'s sign, joined by a rounded bend rather than a
  /// sharp right angle so it reads as a soft crop mark, not a box corner.
  void _drawCorner(
    Canvas canvas,
    Paint paint,
    Offset corner,
    double armLength,
    double bendRadius,
    double dx,
    double dy,
  ) {
    final path = Path()
      ..moveTo(corner.dx + dx * armLength, corner.dy)
      ..lineTo(corner.dx + dx * bendRadius, corner.dy)
      ..quadraticBezierTo(
        corner.dx,
        corner.dy,
        corner.dx,
        corner.dy + dy * bendRadius,
      )
      ..lineTo(corner.dx, corner.dy + dy * armLength);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FramerLogoPainter oldDelegate) =>
      oldDelegate.color != color;
}
