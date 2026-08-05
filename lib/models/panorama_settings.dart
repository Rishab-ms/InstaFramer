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
  final int tileCount;
  final PanoramaFitMode fitMode;

  /// 0.5–1.0. Only meaningful in [PanoramaFitMode.fit].
  final double scale;

  /// Only meaningful in [PanoramaFitMode.fit].
  final BackgroundType backgroundType;

  final int blurIntensity; // 1-100
  final int imageQuality; // 1-100 (JPEG quality)
  final int tileWidth; // px, per tile

  /// Horizontal nudge of the photo within the canvas, in **tile widths**, so a
  /// given slider position means the same thing at every [tileCount] and
  /// [tileWidth]. 0 = centred, range -0.5..0.5 — a full tile of travel is
  /// enough to move any subject off any seam, and clamping there stops the
  /// photo sliding off the canvas.
  final double seamOffset;

  /// True once the user has dragged the seam slider. Automatic seam placement
  /// must stop re-optimising after that; reset when a new source is picked.
  final bool seamOffsetIsManual;

  const PanoramaSettings({
    required this.tileCount,
    this.fitMode = PanoramaFitMode.fit,
    this.scale = 0.92,
    this.backgroundType = BackgroundType.white,
    this.blurIntensity = 75,
    this.imageQuality = 85,
    this.tileWidth = PanoramaSpec.minTileWidth,
    this.seamOffset = 0.0,
    this.seamOffsetIsManual = false,
  });

  /// Height is derived first so that [canvasWidth] can be an exact multiple of
  /// [tileWidth]. Deriving the height from the canvas width instead would leave
  /// sub-pixel drift that shows up as a duplicated or missing pixel column at a
  /// seam.
  int get tileHeight => (tileWidth / PanoramaSpec.tileRatio).round();

  int get canvasWidth => tileWidth * tileCount;

  int get canvasHeight => tileHeight;

  double get canvasRatio => PanoramaSpec.canvasRatio(tileCount);

  /// Horizontal pixel shift applied when compositing, in canvas pixels.
  int get seamOffsetPx => (seamOffset * tileWidth).round();

  @override
  List<Object?> get props => [
        tileCount,
        fitMode,
        scale,
        backgroundType,
        blurIntensity,
        imageQuality,
        tileWidth,
        seamOffset,
        seamOffsetIsManual,
      ];

  PanoramaSettings copyWith({
    int? tileCount,
    PanoramaFitMode? fitMode,
    double? scale,
    BackgroundType? backgroundType,
    int? blurIntensity,
    int? imageQuality,
    int? tileWidth,
    double? seamOffset,
    bool? seamOffsetIsManual,
  }) {
    return PanoramaSettings(
      tileCount: tileCount ?? this.tileCount,
      fitMode: fitMode ?? this.fitMode,
      scale: scale ?? this.scale,
      backgroundType: backgroundType ?? this.backgroundType,
      blurIntensity: blurIntensity ?? this.blurIntensity,
      imageQuality: imageQuality ?? this.imageQuality,
      tileWidth: tileWidth ?? this.tileWidth,
      seamOffset: seamOffset ?? this.seamOffset,
      seamOffsetIsManual: seamOffsetIsManual ?? this.seamOffsetIsManual,
    );
  }
}
