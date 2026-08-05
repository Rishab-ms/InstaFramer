import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/enums.dart';

/// Fit / Fill segmented toggle.
///
/// Fit: contain-fit, leftover padded with the background, scale active.
/// Fill: cover-fit + centre crop, no bars — background/scale controls are
/// removed from the tree by the caller, not just disabled.
class PanoramaFitModeToggle extends StatelessWidget {
  final PanoramaFitMode fitMode;

  const PanoramaFitModeToggle({super.key, required this.fitMode});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PanoramaFitMode>(
      segments: PanoramaFitMode.values
          .map(
            (mode) => ButtonSegment(value: mode, label: Text(mode.displayName)),
          )
          .toList(),
      selected: {fitMode},
      onSelectionChanged: (selection) {
        context.read<PanoramaBloc>().add(UpdateFitModeEvent(selection.first));
      },
    );
  }
}
