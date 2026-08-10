import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/enums.dart';
import '../../models/panorama_settings.dart';
import '../../models/panorama_spec.dart';
import '../editor/control_button.dart';

/// Tile-count pill row (2..[maxTiles]) with a live canvas-ratio hint, a
/// per-tile resolution readout, and either a bars-vs-cropped consequence
/// line or an empty-tile advice line.
///
/// Counts above [maxTiles] this photo's resolution can't support are simply
/// not shown — an info icon next to the "Tiles" label explains the cap on
/// tap, rather than cluttering the row with pills that can never be picked.
class PanoramaTileCountSelector extends StatelessWidget {
  final PanoramaSettings settings;
  final int maxTiles;
  final int sourceWidth;
  final double sourceAspect;

  const PanoramaTileCountSelector({
    super.key,
    required this.settings,
    required this.maxTiles,
    required this.sourceWidth,
    required this.sourceAspect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileCount = settings.tileCount;
    final fitMode = settings.fitMode;
    final canvasRatio = PanoramaSpec.canvasRatio(tileCount);

    final nativePerTile = sourceWidth ~/ tileCount;
    // Resolution and canvas-ratio used to be two separate caption lines;
    // merged into one so the routine (non-warning) case doesn't read as a
    // wall of gray text under the pill row.
    final resolutionLine = nativePerTile >= PanoramaSpec.minTileWidth
        ? '$tileCount tiles · ${settings.tileWidth}px/slide · '
              '${canvasRatio.toStringAsFixed(2)}:1 canvas'
        : '$tileCount tiles · ${nativePerTile}px/slide — below '
              "Instagram's ${PanoramaSpec.minTileWidth} · "
              '${canvasRatio.toStringAsFixed(2)}:1 canvas';

    // Which dimension has to give depends only on which shape is wider —
    // this sign flip is the entire decision. Matches the 2x2 table in the
    // panorama plan's "UI" section:
    //   Fill, canvas wider than photo  -> top/bottom cropped (photo's tall
    //                                     edges get cut to cover the width)
    //   Fill, canvas narrower          -> sides cropped
    //   Fit,  canvas wider than photo  -> bars left/right (photo pillarboxed)
    //   Fit,  canvas narrower          -> bars above/below (letterboxed)
    final isCanvasWider = canvasRatio > sourceAspect;

    final consequence = fitMode == PanoramaFitMode.fill
        ? (isCanvasWider
              ? 'Top & bottom will be cropped'
              : 'Sides will be cropped')
        : (isCanvasWider ? 'Bars on the left & right' : 'Bars above & below');

    final emptyTiles = _emptyTiles(
      tileCount: tileCount,
      fitMode: fitMode,
      scale: settings.scale,
      seamOffset: settings.seamOffset,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );

    final String secondLine;
    if (emptyTiles.isNotEmpty) {
      final suggestion = _suggestedTileCount(
        maxTiles: maxTiles,
        fitMode: fitMode,
        scale: settings.scale,
        sourceAspect: sourceAspect,
      );
      final tileList = emptyTiles.join(', ');
      secondLine =
          '⚠ ${emptyTiles.length == 1 ? "Tile" : "Tiles"} $tileList '
          '${emptyTiles.length == 1 ? "is" : "are"} mostly empty — try '
          '$suggestion tiles';
    } else {
      secondLine = consequence;
    }

    // Only counts above maxTiles are hidden, not just disabled — this photo's
    // resolution simply can't support them, and a mystery cap explained on
    // tap (see the info icon below) is less cluttered than showing options
    // that can never be picked.
    final hasHiddenCounts = maxTiles < PanoramaSpec.maxTilesCap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tiles', style: theme.textTheme.labelLarge),
            if (hasHiddenCounts)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "This photo is ${sourceWidth}px wide, so it only "
                        'supports up to $maxTiles tiles — more would drop '
                        "each slide below Instagram's "
                        '${PanoramaSpec.minTileWidth}px minimum.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.error_outline,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (
                var count = PanoramaSpec.minTiles;
                count <= maxTiles;
                count++
              )
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ControlButton(
                    icon: Icons.view_column_outlined,
                    label: '$count',
                    isSelected: tileCount == count,
                    onTap: () {
                      context.read<PanoramaBloc>().add(
                        UpdateTileCountEvent(count),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          resolutionLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        _AspectRatioCompare(
          canvasRatio: canvasRatio,
          sourceAspect: sourceAspect,
        ),
        const SizedBox(height: 4),
        Text(
          secondLine,
          style: theme.textTheme.bodySmall?.copyWith(
            color: emptyTiles.isNotEmpty
                ? theme.colorScheme.error
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 1-indexed numbers of tiles whose photo coverage is below 50% — see
  /// Smart Defaults B. Mirrors `ImageProcessor`'s Fit (`_overlayScaledImage`)
  /// / Fill (full coverage, no bars) geometry to find where the photo
  /// actually sits on the canvas.
  static List<int> _emptyTiles({
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double scale,
    required double seamOffset,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    if (fitMode == PanoramaFitMode.fill) {
      return const []; // Fill always covers the full canvas, no bars.
    }

    final photoSpan = scale * math.min(1.0, sourceAspect / canvasRatio);
    final slack = (1.0 - photoSpan) / 2;
    final offsetFrac = (seamOffset / tileCount).clamp(-slack, slack);
    final photoStart = 0.5 - photoSpan / 2 + offsetFrac;
    final photoEnd = 0.5 + photoSpan / 2 + offsetFrac;

    final empty = <int>[];
    for (var k = 0; k < tileCount; k++) {
      final tileStart = k / tileCount;
      final tileEnd = (k + 1) / tileCount;
      final overlap =
          (math.min(tileEnd, photoEnd) - math.max(tileStart, photoStart)).clamp(
            0.0,
            1.0 / tileCount,
          );
      final coverage = overlap * tileCount;
      if (coverage < 0.5) empty.add(k + 1);
    }
    return empty;
  }

  /// Largest tile count in `[minTiles, maxTiles]` where every tile clears
  /// the coverage threshold at a **centred** offset. Deliberately ignores
  /// the current seam-nudge: that slider is a fine-tuning override, not a
  /// factor in "how many tiles should this be" advice.
  static int _suggestedTileCount({
    required int maxTiles,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
  }) {
    for (var count = maxTiles; count > PanoramaSpec.minTiles; count--) {
      final canvasRatio = PanoramaSpec.canvasRatio(count);
      final empty = _emptyTiles(
        tileCount: count,
        fitMode: fitMode,
        scale: scale,
        seamOffset: 0,
        sourceAspect: sourceAspect,
        canvasRatio: canvasRatio,
      );
      if (empty.isEmpty) return count;
    }
    return PanoramaSpec.minTiles;
  }
}

/// Small side-by-side rectangles showing canvas shape vs. photo shape — a
/// glance at "these are pretty different" is faster than reading two decimal
/// ratios and comparing them mentally.
class _AspectRatioCompare extends StatelessWidget {
  static const double _maxDim = 24.0;

  final double canvasRatio;
  final double sourceAspect;

  const _AspectRatioCompare({
    required this.canvasRatio,
    required this.sourceAspect,
  });

  Size _sizeFor(double ratio) {
    return ratio >= 1
        ? Size(_maxDim, _maxDim / ratio)
        : Size(_maxDim * ratio, _maxDim);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final canvasSize = _sizeFor(canvasRatio);
    final photoSize = _sizeFor(sourceAspect);

    Widget swatch(Size size, Color color) => SizedBox(
      width: _maxDim,
      height: _maxDim,
      child: Center(
        child: Container(
          width: size.width,
          height: size.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );

    return Row(
      children: [
        swatch(canvasSize, theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text('Canvas ${canvasRatio.toStringAsFixed(2)}:1', style: captionStyle),
        const SizedBox(width: 16),
        swatch(photoSize, theme.colorScheme.outline),
        const SizedBox(width: 6),
        Text('Photo ${sourceAspect.toStringAsFixed(2)}:1', style: captionStyle),
      ],
    );
  }
}
