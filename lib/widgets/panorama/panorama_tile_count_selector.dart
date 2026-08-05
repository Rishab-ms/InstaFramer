import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/enums.dart';
import '../../models/panorama_spec.dart';
import '../editor/control_button.dart';

/// Tile-count pill row (2..maxTiles) with a live canvas-ratio hint and a
/// consequence line describing what the mismatch between [sourceAspect] and
/// the canvas ratio means for the current [fitMode] (bars vs. cropping).
///
/// The empty-tile advice line and the per-tile resolution readout that
/// disables counts above `maxTiles` (rather than hiding them) are Step 5
/// (Smart Defaults).
class PanoramaTileCountSelector extends StatelessWidget {
  final int tileCount;
  final int maxTiles;
  final double sourceAspect;
  final PanoramaFitMode fitMode;

  const PanoramaTileCountSelector({
    super.key,
    required this.tileCount,
    required this.maxTiles,
    required this.sourceAspect,
    required this.fitMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canvasRatio = PanoramaSpec.canvasRatio(tileCount);
    final isCanvasWider = canvasRatio > sourceAspect;

    final consequence = fitMode == PanoramaFitMode.fill
        ? (isCanvasWider
              ? 'Top & bottom will be cropped'
              : 'Sides will be cropped')
        : (isCanvasWider ? 'Bars on the left & right' : 'Bars above & below');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tiles', style: theme.textTheme.labelLarge),
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
          '${canvasRatio.toStringAsFixed(2)}:1 canvas · photo '
          '${sourceAspect.toStringAsFixed(2)}:1',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          consequence,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
