import 'enums.dart';
import 'panorama_geometry.dart';

/// Constants and eligibility rules for the panorama carousel.
///
/// N tiles of a chosen [PanoramaTileRatio] placed side by side form a single
/// canvas of aspect ratio `N * tileRatio`, so panorama is the framer
/// pipeline applied to a derived canvas ratio plus a slice step.
///
/// Takes plain [int] dimensions rather than an `AssetEntity` so the models
/// layer never imports `photo_manager`. Callers pass the orientation-normalised
/// dimensions (`orientatedWidth` / `orientatedHeight`).
class PanoramaSpec {
  const PanoramaSpec._();

  static const int minTiles = 2;
  static const int maxTilesCap = 10;
  static const double minSourceAspect = 1.2;

  /// Instagram's minimum useful slide width. Used for **both** the eligibility
  /// gate (2 tiles worth) and the max-tile cap. Deliberately the constant and
  /// not the user's configured tile width: eligibility is evaluated before
  /// preferences are loaded, and this keeps the gate identical to the editor's
  /// cap.
  static const int minTileWidth = 1080;

  /// Aspect ratio of the full canvas that [tileCount] tiles of [tileRatio]
  /// form.
  static double canvasRatio(int tileCount, double tileRatio) =>
      tileCount * tileRatio;

  /// Decides whether a source photo can become a panorama carousel.
  ///
  /// Checks run in order and the first failure wins, so the reason surfaced to
  /// the user is always the most actionable one. [tileRatio] only feeds
  /// [PanoramaEligibility.suggestedTiles] — eligibility itself and [maxTiles]
  /// are shape-independent (a resolution/aspect check and a resolution cap
  /// respectively), so evaluating once at pick-time (against whatever ratio
  /// a fresh [PanoramaSettings] starts at) stays valid even if the user
  /// later switches ratio.
  static PanoramaEligibility evaluate({
    required int sourceWidth,
    required int sourceHeight,
    required double tileRatio,
  }) {
    if (sourceWidth == 0 || sourceHeight == 0) {
      return const PanoramaEligibility._ineligible(
        "Couldn't read this photo's dimensions.",
      );
    }

    final aspect = sourceWidth / sourceHeight;
    if (aspect <= minSourceAspect) {
      return const PanoramaEligibility._ineligible(
        "This photo isn't wide enough for a panorama — it needs to be wider "
        'than 6:5.',
      );
    }

    if (sourceWidth < minTileWidth * minTiles) {
      return const PanoramaEligibility._ineligible(
        'This photo is too low-resolution for a panorama — it needs to be at '
        'least ${minTileWidth * minTiles}px wide.',
      );
    }

    final maxTiles = (sourceWidth ~/ minTileWidth).clamp(minTiles, maxTilesCap);
    final suggestedTiles = (aspect / tileRatio).round().clamp(
      minTiles,
      maxTiles,
    );

    return PanoramaEligibility._eligible(
      maxTiles: maxTiles,
      suggestedTiles: suggestedTiles,
    );
  }

  /// 1-indexed numbers of tiles whose photo coverage is below 50% — see
  /// Smart Defaults B. Thin wrapper over [PanoramaGeometry], which owns the
  /// fit/fill placement maths for every caller.
  static List<int> emptyTiles({
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double scale,
    required double cropOffsetX,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    return PanoramaGeometry.resolve(
      fitMode: fitMode,
      tileCount: tileCount,
      scale: scale,
      cropOffsetX: cropOffsetX,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    ).emptyTiles();
  }

  /// Largest seam nudge (in tile widths) that moves the photo at all, given
  /// the current framing. Bounds the editor's seam slider so its track maps
  /// 1:1 onto travel the render will honour — the previous fixed ±0.5 range
  /// left most of the track inert whenever the photo nearly filled the canvas.
  static double maxCropOffsetX({
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    return PanoramaGeometry.resolve(
      fitMode: fitMode,
      tileCount: tileCount,
      scale: scale,
      cropOffsetX: 0,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    ).maxCropOffsetX;
  }

  /// Snaps a raw vertical nudge to centre or to either rule-of-thirds
  /// alignment when it lands close enough, and returns it unchanged
  /// otherwise.
  ///
  /// Magnetic rather than stepped: the slider stays continuous so fine
  /// placement is still possible, and only the three positions that mean
  /// something get a pull. [snapFraction] is the catch radius as a share of
  /// the full travel — small, because a snap that grabs from far away stops
  /// feeling like assistance and starts feeling like a control that won't do
  /// what it's told.
  static double snapCropOffsetY(
    double value, {
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double sourceAspect,
    required double canvasRatio,
    double snapFraction = 0.06,
  }) {
    final geometry = PanoramaGeometry.resolve(
      fitMode: fitMode,
      tileCount: tileCount,
      scale: 1.0,
      cropOffsetX: 0,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );
    final maxOffset = geometry.maxCropOffsetY;
    if (maxOffset <= 0) return 0;

    final thirds = geometry.thirdsCropOffsetY;
    final radius = maxOffset * snapFraction;

    for (final target in [0.0, thirds, -thirds]) {
      if ((value - target).abs() <= radius) return target;
    }
    return value;
  }

  /// Largest vertical nudge (in canvas heights) the current framing allows —
  /// how much of the source Fill's crop is discarding above and below. Always
  /// 0 in Fit, which crops nothing and stays vertically centred.
  static double maxCropOffsetY({
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    return PanoramaGeometry.resolve(
      fitMode: fitMode,
      tileCount: tileCount,
      // Scale only affects Fit's contain-fit size; Fill's crop window doesn't
      // depend on it, and Fit has no vertical travel either way.
      scale: 1.0,
      cropOffsetX: 0,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    ).maxCropOffsetY;
  }

  /// Largest tile count in `[minTiles, maxTiles]` where every tile clears
  /// the coverage threshold at a **centred** offset. Deliberately ignores
  /// the current seam-nudge: that slider is a fine-tuning override, not a
  /// factor in "how many tiles should this be" advice.
  static int suggestedTileCount({
    required int maxTiles,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double tileRatio,
  }) {
    for (var count = maxTiles; count > minTiles; count--) {
      final empty = emptyTiles(
        tileCount: count,
        fitMode: fitMode,
        scale: scale,
        cropOffsetX: 0,
        sourceAspect: sourceAspect,
        canvasRatio: canvasRatio(count, tileRatio),
      );
      if (empty.isEmpty) return count;
    }
    return minTiles;
  }
}

/// Result of [PanoramaSpec.evaluate].
///
/// When [isEligible] is false, [reason] is the user-facing explanation and the
/// tile counts are meaningless.
class PanoramaEligibility {
  final bool isEligible;
  final String? reason;
  final int maxTiles;
  final int suggestedTiles;

  const PanoramaEligibility._ineligible(String this.reason)
    : isEligible = false,
      maxTiles = 0,
      suggestedTiles = 0;

  const PanoramaEligibility._eligible({
    required this.maxTiles,
    required this.suggestedTiles,
  }) : isEligible = true,
       reason = null;
}
