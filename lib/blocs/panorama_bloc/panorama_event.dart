import 'dart:ui' show Color;

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

/// Event to update the background to a solid color, e.g. one of the photo's
/// own suggested swatches. Overrides [UpdatePanoramaBackgroundTypeEvent]'s
/// choice entirely until white/black/blur is picked again. See
/// `plans/color_picking.md`. Only meaningful in Fit mode.
class UpdatePanoramaBackgroundColorEvent extends PanoramaEvent {
  final Color color;

  const UpdatePanoramaBackgroundColorEvent(this.color);

  @override
  List<Object?> get props => [color];
}

/// Event to update the blur intensity. Only affects the extendedBlur background.
class UpdatePanoramaBlurIntensityEvent extends PanoramaEvent {
  final int intensity;

  const UpdatePanoramaBlurIntensityEvent(this.intensity);

  @override
  List<Object?> get props => [intensity];
}

/// Event to update the per-tile aspect ratio (4:5 portrait or 1:1 square).
class UpdatePanoramaTileRatioEvent extends PanoramaEvent {
  final PanoramaTileRatio tileRatio;

  const UpdatePanoramaTileRatioEvent(this.tileRatio);

  @override
  List<Object?> get props => [tileRatio];
}

/// Event to update the photo's corner-rounding amount, as a fraction of the
/// photo's own shorter side (0 = square corners). Only meaningful in Fit
/// mode. Fill has no background behind the photo for rounded corners to
/// reveal.
class UpdatePanoramaCornerRadiusEvent extends PanoramaEvent {
  final double cornerRadius;

  const UpdatePanoramaCornerRadiusEvent(this.cornerRadius);

  @override
  List<Object?> get props => [cornerRadius];
}

/// Event to update the horizontal seam-nudge offset (in tile widths, -0.5..0.5).
///
/// Not enumerated in the plan's nine-event architecture list, but required by
/// Product Decision 3 ("Seam-nudge IS in V1") and the Step 2 gate, which
/// requires the seam-nudge slider to reflow correctly alongside tile count,
/// Fit/Fill and scale. Marks `cropOffsetXIsManual` so Step 5's automatic
/// seam-placement re-optimization knows to stop touching this value.
class UpdatePanoramaCropOffsetXEvent extends PanoramaEvent {
  final double cropOffsetX;

  const UpdatePanoramaCropOffsetXEvent(this.cropOffsetX);

  @override
  List<Object?> get props => [cropOffsetX];
}

/// Moves the photo up or down within the canvas, choosing what Fill's crop
/// keeps. Separate from [UpdatePanoramaCropOffsetXEvent] because it positions
/// the crop, not the seams. See `PanoramaSettings.cropOffsetY`.
class UpdatePanoramaCropOffsetYEvent extends PanoramaEvent {
  final double cropOffsetY;

  const UpdatePanoramaCropOffsetYEvent(this.cropOffsetY);

  @override
  List<Object?> get props => [cropOffsetY];
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
