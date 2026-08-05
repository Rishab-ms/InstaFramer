/// Constants and eligibility rules for the panorama carousel.
///
/// N tiles of 4:5 placed side by side form a single canvas of aspect ratio
/// `N * 0.8`, so panorama is the framer pipeline applied to a derived canvas
/// ratio plus a slice step.
///
/// Takes plain [int] dimensions rather than an `AssetEntity` so the models
/// layer never imports `photo_manager`. Callers pass the orientation-normalised
/// dimensions (`orientatedWidth` / `orientatedHeight`).
class PanoramaSpec {
  const PanoramaSpec._();

  static const double tileRatio = 4 / 5; // 0.8
  static const int minTiles = 2;
  static const int maxTilesCap = 10;
  static const double minSourceAspect = 1.2;

  /// Instagram's minimum useful slide width. Used for **both** the eligibility
  /// gate (2 tiles worth) and the max-tile cap. Deliberately the constant and
  /// not the user's configured tile width: eligibility is evaluated before
  /// preferences are loaded, and this keeps the gate identical to the editor's
  /// cap.
  static const int minTileWidth = 1080;

  /// Aspect ratio of the full canvas that [tileCount] tiles form.
  static double canvasRatio(int tileCount) => tileCount * tileRatio;

  /// Decides whether a source photo can become a panorama carousel.
  ///
  /// Checks run in order and the first failure wins, so the reason surfaced to
  /// the user is always the most actionable one.
  static PanoramaEligibility evaluate({
    required int sourceWidth,
    required int sourceHeight,
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
    final suggestedTiles = (aspect / tileRatio).round().clamp(minTiles, maxTiles);

    return PanoramaEligibility._eligible(
      maxTiles: maxTiles,
      suggestedTiles: suggestedTiles,
    );
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
  })  : isEligible = true,
        reason = null;
}
