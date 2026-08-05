import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/panorama_settings.dart';

/// Base class for all panorama-related states.
///
/// All PanoramaBloc states extend this class and follow the naming
/// convention of ending with "State" for clarity.
abstract class PanoramaState extends Equatable {
  const PanoramaState();

  @override
  List<Object?> get props => [];
}

/// Initial state before a source photo has been picked.
class PanoramaInitialState extends PanoramaState {
  const PanoramaInitialState();
}

/// Terminal state when the picked source fails `PanoramaSpec.evaluate`.
///
/// [reason] is the user-facing explanation, surfaced as a snackbar on Home —
/// the editor is never pushed for an ineligible source.
class PanoramaIneligibleState extends PanoramaState {
  final String reason;

  const PanoramaIneligibleState(this.reason);

  @override
  List<Object?> get props => [reason];
}

/// Main editing state once an eligible source is loaded.
///
/// [sourceWidth] / [sourceHeight] are orientation-normalised
/// (`orientatedWidth` / `orientatedHeight`) so the UI never has to touch
/// `AssetEntity` dimension quirks directly.
class PanoramaReadyState extends PanoramaState {
  final AssetEntity source;
  final int sourceWidth;
  final int sourceHeight;
  final int maxTiles;
  final PanoramaSettings settings;

  const PanoramaReadyState({
    required this.source,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.maxTiles,
    required this.settings,
  });

  double get sourceAspect => sourceWidth / sourceHeight;

  @override
  List<Object?> get props => [
    source,
    sourceWidth,
    sourceHeight,
    maxTiles,
    settings,
  ];

  PanoramaReadyState copyWith({PanoramaSettings? settings}) {
    return PanoramaReadyState(
      source: source,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      maxTiles: maxTiles,
      settings: settings ?? this.settings,
    );
  }
}
