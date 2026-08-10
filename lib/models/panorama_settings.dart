import 'dart:ui' show Color;

import 'package:equatable/equatable.dart';
import 'enums.dart';
import 'panorama_spec.dart';

/// Settings for rendering a panorama carousel.
///
/// Standalone rather than wrapping `PhotoSettings`: there is no aspect ratio to
/// choose here because the canvas ratio is *derived* from [tileCount], and
/// pushing panorama concepts into `PhotoSettings` would leak them into the
/// framer's isolate and `copyWith`.
class PanoramaSettings extends Equatable {
  /// The scale a fresh panorama (or a reset zoom slider) starts at.
  ///
  /// Full size, unlike the framer's remembered `lastUsedScale`. The framer's
  /// zoom exists to *inset* a photo inside a frame, so a personal default
  /// below 1.0 is the whole point there. Panorama's goal is the opposite: get
  /// the photo as large as it can go without cropping anything, which is
  /// exactly contain-fit at 1.0. Zooming out only trades photo for background
  /// bars and starts emptying tiles, so it belongs behind a deliberate drag,
  /// never as an opening state.
  static const double defaultScale = 1.0;

  final int tileCount;
  final PanoramaFitMode fitMode;

  /// 0.5–1.0. Only meaningful in [PanoramaFitMode.fit].
  final double scale;

  /// Only meaningful in [PanoramaFitMode.fit].
  final BackgroundType backgroundType;

  /// A color picked from the photo's own suggested palette (see
  /// `plans/color_picking.md`), overriding [backgroundType] entirely when
  /// set. Not folded into [BackgroundType] itself — that enum is shared with
  /// the framer's `PhotoSettings`, which has no picker for this yet, and
  /// adding a value only panorama can produce would leak a panorama-only
  /// concept into the framer's exhaustive switches. Only meaningful in
  /// [PanoramaFitMode.fit].
  final Color? backgroundColor;

  final int blurIntensity; // 1-100
  final int imageQuality; // 1-100 (JPEG quality)
  final int tileWidth; // px, per tile
  final PanoramaTileRatio tileRatio;

  /// Corner rounding applied to the photo itself, as a fraction of the
  /// photo's own shorter side (0 = square, e.g. 0.3 = 30%). Only meaningful
  /// in [PanoramaFitMode.fit] — Fill has no background behind the photo for
  /// rounded corners to reveal.
  final double cornerRadius;

  /// Horizontal nudge of the photo within the canvas, in **tile widths**, so a
  /// given slider position means the same thing at every [tileCount] and
  /// [tileWidth]. 0 = centred; positive moves the photo right in **both** fit
  /// modes.
  ///
  /// Bounded by `PanoramaSpec.maxCropOffsetX` for the current framing, not by a
  /// fixed ±0.5: how far the photo can slide depends on zoom, tile count and
  /// fit mode, and storing an offset beyond that bound means the stored value
  /// and the rendered position disagree. `PanoramaBloc` re-clamps this
  /// whenever the framing changes.
  final double cropOffsetX;

  /// Vertical nudge of the photo within the canvas, in **canvas heights**.
  /// 0 = centred; positive moves the photo down, revealing more of the
  /// source's top — matching [cropOffsetX]'s "positive moves the photo toward
  /// the increasing axis" convention.
  ///
  /// A separate field rather than a Y component of [cropOffsetX] because the
  /// two answer different questions. [cropOffsetX] positions the *seams*, which
  /// only run vertically, and carries automatic placement plus its own
  /// manual-override flag. This positions the *crop*, deciding what gets
  /// thrown away, and is purely manual — there is no vertical equivalent of
  /// the seam energy profile because there is no horizontal cut to avoid.
  ///
  /// Only meaningful in [PanoramaFitMode.fill]. Fit crops nothing, so a
  /// vertical nudge there would only slide the photo between its top and
  /// bottom bars; `PanoramaGeometry` pins it to 0 in that mode.
  final double cropOffsetY;

  const PanoramaSettings({
    required this.tileCount,
    this.fitMode = PanoramaFitMode.fit,
    this.scale = defaultScale,
    this.backgroundType = BackgroundType.white,
    this.backgroundColor,
    this.blurIntensity = 75,
    this.imageQuality = 85,
    this.tileWidth = PanoramaSpec.minTileWidth,
    this.tileRatio = PanoramaTileRatio.portrait,
    this.cornerRadius = 0.0,
    this.cropOffsetX = 0.0,
    this.cropOffsetY = 0.0,
  });

  /// Height is derived first so that [canvasWidth] can be an exact multiple of
  /// [tileWidth]. Deriving the height from the canvas width instead would leave
  /// sub-pixel drift that shows up as a duplicated or missing pixel column at a
  /// seam.
  int get tileHeight => (tileWidth / tileRatio.ratio).round();

  int get canvasWidth => tileWidth * tileCount;

  int get canvasHeight => tileHeight;

  double get canvasRatio =>
      PanoramaSpec.canvasRatio(tileCount, tileRatio.ratio);

  /// Horizontal pixel shift applied when compositing, in canvas pixels.
  int get cropOffsetXPx => (cropOffsetX * tileWidth).round();

  /// Vertical pixel shift applied when compositing, in canvas pixels. The
  /// canvas is exactly one tile tall, so a canvas height is [tileHeight].
  int get cropOffsetYPx => (cropOffsetY * tileHeight).round();

  @override
  List<Object?> get props => [
    tileCount,
    fitMode,
    scale,
    backgroundType,
    backgroundColor,
    blurIntensity,
    imageQuality,
    tileWidth,
    tileRatio,
    cornerRadius,
    cropOffsetX,
    cropOffsetY,
  ];

  PanoramaSettings copyWith({
    int? tileCount,
    PanoramaFitMode? fitMode,
    double? scale,
    BackgroundType? backgroundType,
    Color? backgroundColor,
    // `backgroundColor: null` above is indistinguishable from "leave it
    // alone" under the usual `?? this.field` pattern, but switching to
    // White/Black/Blur must be able to actually clear a previously-picked
    // color. This flag is the explicit way to say "clear it" rather than
    // "wasn't passed".
    bool clearBackgroundColor = false,
    int? blurIntensity,
    int? imageQuality,
    int? tileWidth,
    PanoramaTileRatio? tileRatio,
    double? cornerRadius,
    double? cropOffsetX,
    double? cropOffsetY,
  }) {
    return PanoramaSettings(
      tileCount: tileCount ?? this.tileCount,
      fitMode: fitMode ?? this.fitMode,
      scale: scale ?? this.scale,
      backgroundType: backgroundType ?? this.backgroundType,
      backgroundColor: clearBackgroundColor
          ? null
          : (backgroundColor ?? this.backgroundColor),
      blurIntensity: blurIntensity ?? this.blurIntensity,
      imageQuality: imageQuality ?? this.imageQuality,
      tileWidth: tileWidth ?? this.tileWidth,
      tileRatio: tileRatio ?? this.tileRatio,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      cropOffsetX: cropOffsetX ?? this.cropOffsetX,
      cropOffsetY: cropOffsetY ?? this.cropOffsetY,
    );
  }
}
