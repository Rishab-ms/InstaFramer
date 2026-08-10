import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';

/// Export trigger, used in the full-screen "preview like Instagram" screen
/// rather than the main editor — exporting is the decision the user makes
/// after checking how the carousel will actually look, not before.
///
/// The EXIF note (`ImageProcessor.processPanorama` writes no EXIF onto tiles
/// at all — see the panorama plan's EXIF section, a real divergence from the
/// framer's `preserveMetadata` toggle) lives as a footnote on
/// [PanoramaProcessingView] instead of here, alongside "Don't leave this
/// page" — the moment export is actually running, not the moment it's
/// requested.
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
    return FilledButton.icon(
      onPressed: () {
        context.read<PanoramaBloc>().add(const ExportPanoramaEvent());
        onExport?.call();
      },
      icon: const Icon(Icons.ios_share),
      label: Text('Export $tileCount tiles'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
