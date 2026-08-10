import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';

/// Export trigger, used in the full-screen "preview like Instagram" screen
/// rather than the main editor — exporting is the decision the user makes
/// after checking how the carousel will actually look, not before.
///
/// Carries the EXIF note beneath the button rather than tucking it into
/// preferences — `ImageProcessor.processPanorama` writes no EXIF onto tiles
/// at all (see the panorama plan's EXIF section), which is a real divergence
/// from the framer's `preserveMetadata` toggle and needs to be visible at the
/// point of the decision.
class PanoramaExportButton extends StatelessWidget {
  final int tileCount;

  /// Called after `ExportPanoramaEvent` is dispatched — the caller decides
  /// what happens to its own navigation (e.g. popping back to the editor,
  /// whose `BlocConsumer` owns the exporting/success/error UI); this widget
  /// only owns the button itself.
  final VoidCallback? onExport;

  const PanoramaExportButton({
    super.key,
    required this.tileCount,
    this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        FilledButton.icon(
          onPressed: () {
            context.read<PanoramaBloc>().add(const ExportPanoramaEvent());
            onExport?.call();
          },
          icon: const Icon(Icons.ios_share),
          label: Text('Export $tileCount tiles'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        const SizedBox(height: 8),
        Text(
          "Camera and location info isn't copied to panorama tiles.",
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
