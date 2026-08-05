import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/panorama_spec.dart';
import '../editor/control_button.dart';

/// Tile-count pill row (2..maxTiles) with a live canvas-ratio hint.
///
/// Per-tile resolution readout and the empty-tile advice line are Step 5
/// (Smart Defaults) — this only shows the canvas ratio for now.
class PanoramaTileCountSelector extends StatelessWidget {
  final int tileCount;
  final int maxTiles;

  const PanoramaTileCountSelector({
    super.key,
    required this.tileCount,
    required this.maxTiles,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canvasRatio = PanoramaSpec.canvasRatio(tileCount);

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
          '${canvasRatio.toStringAsFixed(2)}:1 canvas',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
