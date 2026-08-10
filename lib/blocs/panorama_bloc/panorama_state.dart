import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/enums.dart';
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

  /// Up to 6 colors suggested from [source]'s own palette, offered alongside
  /// White/Black/Blur — see `plans/color_picking.md`. Excluded from [props]:
  /// derived purely from [source], which is already in [props], so comparing
  /// it too would cost a list comparison on every settings change for no
  /// additional information.
  final List<Color> suggestedColors;

  const PanoramaReadyState({
    required this.source,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.maxTiles,
    required this.settings,
    this.suggestedColors = const [],
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
      suggestedColors: suggestedColors,
    );
  }
}

/// Export in progress. See [PanoramaExportPhase] for what the two phases mean.
///
/// Deliberately does not carry `source`/`settings` — the processing view is a
/// generic tile-count visualisation, not a live render of the photo, so
/// nothing here duplicates the framer's `PhotosProcessingState.photos`
/// approach.
class PanoramaExportingState extends PanoramaState {
  final PanoramaExportPhase phase;
  final int saved;
  final int total;

  const PanoramaExportingState({
    required this.phase,
    required this.saved,
    required this.total,
  });

  double get progress => total == 0 ? 0 : saved / total;

  @override
  List<Object?> get props => [phase, saved, total];
}

/// Terminal state once every tile has been saved to the gallery.
class PanoramaExportedState extends PanoramaState {
  final int tileCount;

  const PanoramaExportedState(this.tileCount);

  @override
  List<Object?> get props => [tileCount];
}

/// Terminal-per-attempt error state.
///
/// [previous] is the [PanoramaReadyState] to return to — carried on the
/// event/state rather than re-emitted via a `Future.delayed` cycle, which the
/// Development Rules forbid (see `PhotoBloc._onExportAllPhotos` for the
/// anti-pattern this avoids). The UI shows the error, then dispatches
/// `DismissPanoramaErrorEvent`, whose handler emits [previous] back.
class PanoramaErrorState extends PanoramaState {
  final String message;
  final PanoramaReadyState previous;

  const PanoramaErrorState({required this.message, required this.previous});

  @override
  List<Object?> get props => [message, previous];
}
