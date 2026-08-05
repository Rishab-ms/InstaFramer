import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/enums.dart';

/// Base class for all panorama-related events.
///
/// All PanoramaBloc events extend this class and follow the naming
/// convention of ending with "Event" for clarity.
abstract class PanoramaEvent extends Equatable {
  const PanoramaEvent();

  @override
  List<Object?> get props => [];
}

/// Event dispatched when the user picks a single photo for the panorama flow.
///
/// Triggers eligibility evaluation via `PanoramaSpec.evaluate` and
/// transitions to [PanoramaReadyState] or [PanoramaIneligibleState].
class PanoramaSourceSelectedEvent extends PanoramaEvent {
  final AssetEntity source;

  const PanoramaSourceSelectedEvent(this.source);

  @override
  List<Object?> get props => [source];
}

/// Event to update the number of tiles the canvas is sliced into.
class UpdateTileCountEvent extends PanoramaEvent {
  final int tileCount;

  const UpdateTileCountEvent(this.tileCount);

  @override
  List<Object?> get props => [tileCount];
}

/// Event to toggle between Fit (contain, padded) and Fill (cover, cropped).
class UpdateFitModeEvent extends PanoramaEvent {
  final PanoramaFitMode fitMode;

  const UpdateFitModeEvent(this.fitMode);

  @override
  List<Object?> get props => [fitMode];
}

/// Event to update the photo scale/zoom level. Only meaningful in Fit mode.
class UpdatePanoramaScaleEvent extends PanoramaEvent {
  final double scale;

  const UpdatePanoramaScaleEvent(this.scale);

  @override
  List<Object?> get props => [scale];
}

/// Event to update the background type. Only meaningful in Fit mode.
class UpdatePanoramaBackgroundTypeEvent extends PanoramaEvent {
  final BackgroundType backgroundType;

  const UpdatePanoramaBackgroundTypeEvent(this.backgroundType);

  @override
  List<Object?> get props => [backgroundType];
}

/// Event to update the blur intensity. Only affects the extendedBlur background.
class UpdatePanoramaBlurIntensityEvent extends PanoramaEvent {
  final int intensity;

  const UpdatePanoramaBlurIntensityEvent(this.intensity);

  @override
  List<Object?> get props => [intensity];
}

/// Event to update the horizontal seam-nudge offset (in tile widths, -0.5..0.5).
///
/// Not enumerated in the plan's nine-event architecture list, but required by
/// Product Decision 3 ("Seam-nudge IS in V1") and the Step 2 gate, which
/// requires the seam-nudge slider to reflow correctly alongside tile count,
/// Fit/Fill and scale. Marks `seamOffsetIsManual` so Step 5's automatic
/// seam-placement re-optimization knows to stop touching this value.
class UpdatePanoramaSeamOffsetEvent extends PanoramaEvent {
  final double seamOffset;

  const UpdatePanoramaSeamOffsetEvent(this.seamOffset);

  @override
  List<Object?> get props => [seamOffset];
}

/// Event to trigger panorama export. Wired in Step 3.
class ExportPanoramaEvent extends PanoramaEvent {
  const ExportPanoramaEvent();
}

/// Event to dismiss a panorama error and return to the prior ready state.
/// Wired in Step 3.
class DismissPanoramaErrorEvent extends PanoramaEvent {
  const DismissPanoramaErrorEvent();
}

/// Event to clear panorama state and reset to initial.
class ClearPanoramaEvent extends PanoramaEvent {
  const ClearPanoramaEvent();
}
