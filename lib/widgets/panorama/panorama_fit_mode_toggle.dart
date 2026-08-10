import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../models/enums.dart';
import '../editor/control_button.dart';

/// Fit / Fill toggle.
///
/// Fit: contain-fit, leftover padded with the background, scale active.
/// Fill: cover-fit + centre crop, no bars — background/scale controls are
/// removed from the tree by the caller, not just disabled.
///
/// Built from [ControlButton] rather than the stock `SegmentedButton` so it
/// shares the pill styling used everywhere else on this screen (tile count,
/// background type) instead of looking like a different design system.
class PanoramaFitModeToggle extends StatelessWidget {
  final PanoramaFitMode fitMode;

  const PanoramaFitModeToggle({super.key, required this.fitMode});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final mode in PanoramaFitMode.values) ...[
          if (mode != PanoramaFitMode.values.first) const SizedBox(width: 8),
          ControlButton(
            icon: mode == PanoramaFitMode.fit
                ? Icons.fit_screen_outlined
                : Icons.crop_free,
            label: mode.displayName,
            isSelected: fitMode == mode,
            onTap: () {
              context.read<PanoramaBloc>().add(UpdateFitModeEvent(mode));
            },
          ),
        ],
      ],
    );
  }
}
