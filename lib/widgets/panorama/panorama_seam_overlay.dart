import 'package:flutter/material.dart';

/// Visual seam guides over the panorama canvas — a vertical border between
/// each tile plus a centred tile-number badge.
///
/// Pixel-accurate regardless of fit mode: the tiles are exact equal
/// fractions of the canvas, so this is an overlay, not derived from the
/// rendered image.
class PanoramaSeamOverlay extends StatelessWidget {
  final int tileCount;

  const PanoramaSeamOverlay({super.key, required this.tileCount});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        children: List.generate(tileCount, (i) {
          final isLast = i == tileCount - 1;
          return Expanded(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  right: isLast
                      ? BorderSide.none
                      : BorderSide(
                          color: Colors.white.withOpacity(0.85),
                          width: 1.5,
                        ),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${i + 1}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
