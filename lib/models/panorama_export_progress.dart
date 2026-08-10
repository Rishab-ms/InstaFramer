import 'enums.dart';

/// Progress emitted by `ExportService.exportPanorama`.
class PanoramaExportProgress {
  final PanoramaExportPhase phase;
  final int saved;
  final int total;

  const PanoramaExportProgress({
    required this.phase,
    required this.saved,
    required this.total,
  });

  double get progress => total == 0 ? 0 : saved / total;
}
