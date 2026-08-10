import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/enums.dart';
import '../../models/panorama_settings.dart';
import '../../models/panorama_spec.dart';
import '../editor/control_button.dart';

/// Tile-ratio toggle (4:5 / 1:1) and tile-count pill row (2..[maxTiles]),
/// with a below-minimum resolution warning (only shown when this photo
/// can't actually deliver Instagram's per-slide minimum) and either a
/// bars-vs-cropped consequence line or an empty-tile advice line.
///
/// Counts above [maxTiles] this photo's resolution can't support are simply
/// not shown. An info icon next to the "Tiles" label explains the cap on
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
    final canvasRatio = PanoramaSpec.canvasRatio(
      tileCount,
      settings.tileRatio.ratio,
    );

    // Per-tile width is Instagram's fixed slide minimum (see
    // PanoramaSettings.tileWidth), always the same number, so it's only
    // worth surfacing when this photo can't actually deliver it.
    final nativePerTile = sourceWidth ~/ tileCount;
    final belowMinimum = nativePerTile < PanoramaSpec.minTileWidth;
    final resolutionWarning = belowMinimum
        ? '$tileCount tiles · ${nativePerTile}px/slide, below '
              "Instagram's ${PanoramaSpec.minTileWidth}px minimum"
        : null;

    // Which dimension has to give depends only on which shape is wider.
    // This sign flip is the entire decision. Matches the 2x2 table in the
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

    final emptyTiles = PanoramaSpec.emptyTiles(
      tileCount: tileCount,
      fitMode: fitMode,
      scale: settings.scale,
      cropOffsetX: settings.cropOffsetX,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );

    // A defect in the current framing outranks the plain consequence of it.
    // Only one line, because a stack of advice reads as noise and the user can
    // only act on one thing at a time anyway.
    //
    // ⚠️ There is a third tier available, `PanoramaSeams.cleanerTileCount`
    // can name a tile count whose slides would divide the photo through
    // quieter pixels, and it is deliberately not shown. See `PanoramaSeams`.
    final String secondLine;
    final Color secondLineColor;
    if (emptyTiles.isNotEmpty) {
      final suggestion = PanoramaSpec.suggestedTileCount(
        maxTiles: maxTiles,
        fitMode: fitMode,
        scale: settings.scale,
        sourceAspect: sourceAspect,
        tileRatio: settings.tileRatio.ratio,
      );
      final tileList = emptyTiles.join(', ');
      secondLine =
          '⚠ ${emptyTiles.length == 1 ? "Tile" : "Tiles"} $tileList '
          '${emptyTiles.length == 1 ? "is" : "are"} mostly empty. Try '
          '$suggestion tiles';
      secondLineColor = theme.colorScheme.error;
    } else {
      secondLine = consequence;
      secondLineColor = theme.colorScheme.onSurfaceVariant;
    }

    // Counts this photo's resolution can't support are hidden rather than
    // disabled, and that needs no explaining: the user sees the pills that
    // exist, not the ones that don't, so a permanent icon would be answering
    // a question nobody can ask. `maxTiles` is `sourceWidth ~/ 1080`, so the
    // old "explain whenever anything is capped" rule fired on every photo
    // narrower than 10800px, which is all of them.
    //
    // The exception is a photo that supports only the minimum: the row then
    // renders a single pill, which reads as broken rather than as a limit.
    // That is the one case worth a word.
    final hasNoChoice = maxTiles <= PanoramaSpec.minTiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final ratio in PanoramaTileRatio.values) ...[
              if (ratio != PanoramaTileRatio.values.first)
                const SizedBox(width: 8),
              ControlButton(
                icon: ratio == PanoramaTileRatio.portrait
                    ? Icons.crop_portrait_outlined
                    : Icons.crop_square_outlined,
                label: ratio.displayName,
                isSelected: settings.tileRatio == ratio,
                onTap: () {
                  context.read<PanoramaBloc>().add(
                    UpdatePanoramaTileRatioEvent(ratio),
                  );
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Tiles', style: theme.textTheme.labelLarge),
            if (hasNoChoice)
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "This photo is ${sourceWidth}px wide, so $maxTiles "
                        'tiles is the only option. Splitting it further '
                        "would drop each slide below Instagram's "
                        '${PanoramaSpec.minTileWidth}px minimum.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                // Information, not an error. Nothing is wrong, the photo
                // just isn't wide enough to divide more ways.
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.info_outline,
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
        if (resolutionWarning != null) ...[
          const SizedBox(height: 4),
          Text(
            resolutionWarning,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          secondLine,
          style: theme.textTheme.bodySmall?.copyWith(color: secondLineColor),
        ),
      ],
    );
  }
}
