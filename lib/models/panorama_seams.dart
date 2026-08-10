import 'dart:math' as math;

import 'enums.dart';

/// Automatic seam placement.
///
/// Seams sit at fixed spacing (one per tile boundary), so there is exactly
/// one free parameter — the horizontal offset — which makes good seam
/// placement a 1-D minimization rather than a vision problem. Pure Dart, no
/// isolate: the expensive part (decoding the photo and computing the energy
/// profile) already happened once via `ImageProcessor.computeEdgeEnergyProfile`
/// — re-optimizing over that cached ~600-element array costs microseconds,
/// cheap enough to re-run on every tile-count or fit-mode change.
class PanoramaSeams {
  const PanoramaSeams._();

  /// Half-width of the energy window scored around each candidate seam, as a
  /// fraction of source width.
  static const double _windowFraction = 0.01;

  /// Sweeps the seam offset across ±0.5 tile widths and returns the value
  /// that minimizes total energy at the interior seams — the offset most
  /// likely to keep every seam out of a face, pole, or building edge.
  ///
  /// [energyProfile] is normalised 0..1 across the **full source width**
  /// (see `ImageProcessor.computeEdgeEnergyProfile`); [tileCount],
  /// [fitMode], [scale], [sourceAspect] and [canvasRatio] describe the
  /// render exactly as `ImageProcessor` will composite it, since scoring a
  /// candidate offset requires mapping each canvas-coordinate seam back into
  /// source coordinates.
  static double bestSeamOffset({
    required List<double> energyProfile,
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double canvasRatio,
    int steps = 200,
  }) {
    if (tileCount < 2 || energyProfile.isEmpty) return 0;

    var bestOffset = 0.0;
    var bestScore = double.infinity;

    for (var step = 0; step <= steps; step++) {
      final candidate = -0.5 + step * (1.0 / steps);
      final score = _scoreOffset(
        candidate,
        energyProfile: energyProfile,
        tileCount: tileCount,
        fitMode: fitMode,
        scale: scale,
        sourceAspect: sourceAspect,
        canvasRatio: canvasRatio,
      );
      if (score < bestScore) {
        bestScore = score;
        bestOffset = candidate;
      }
    }

    return bestOffset;
  }

  static double _scoreOffset(
    double candidateOffset, {
    required List<double> energyProfile,
    required int tileCount,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    var total = 0.0;
    for (var i = 1; i < tileCount; i++) {
      final canvasFrac = i / tileCount;
      final srcFrac = _mapToSource(
        canvasFrac,
        candidateOffset / tileCount,
        fitMode: fitMode,
        scale: scale,
        sourceAspect: sourceAspect,
        canvasRatio: canvasRatio,
      );
      // A seam landing outside the photo (Fit's letterbox bars) is already
      // perfect — nothing to cut through — so it contributes zero, not a
      // penalty.
      if (srcFrac == null) continue;
      total += _windowEnergy(energyProfile, srcFrac);
    }
    return total;
  }

  /// Maps a canvas-fraction position to a source-fraction position,
  /// mirroring `ImageProcessor`'s Fit (`_overlayScaledImage`) and Fill
  /// (`_coverCropResize`) compositing math exactly — this has to match the
  /// real renderer pixel-for-pixel or the "optimal" seam lands somewhere
  /// other than where the tile is actually cut.
  ///
  /// Returns null for a canvas position that falls in Fit's letterbox bars
  /// (no source content there at all).
  static double? _mapToSource(
    double canvasFrac,
    double offsetFrac, {
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double canvasRatio,
  }) {
    switch (fitMode) {
      case PanoramaFitMode.fit:
        // Contain-fit at `scale`, centred, then nudged by offsetFrac and
        // clamped to the slack between the photo and the canvas edge —
        // exactly `_overlayScaledImage`'s geometry.
        final photoSpan = scale * math.min(1.0, sourceAspect / canvasRatio);
        final slack = (1.0 - photoSpan) / 2;
        final clampedOffset = offsetFrac.clamp(-slack, slack);
        final c0 = 0.5 - photoSpan / 2 + clampedOffset;
        final c1 = 0.5 + photoSpan / 2 + clampedOffset;
        if (canvasFrac < c0 || canvasFrac > c1) return null;
        if (c1 == c0) return 0.5;
        return (canvasFrac - c0) / (c1 - c0);

      case PanoramaFitMode.fill:
        // Cover-fit + centre crop, exactly `_coverCropResize`'s geometry.
        // When the canvas is wider-aspect than the source (the common
        // panorama case — canvasRatio grows with tileCount, sourceAspect
        // doesn't), the crop window already spans the full source width, so
        // the seam-nudge has no effect: srcFrac tracks canvasFrac 1:1.
        if (canvasRatio >= sourceAspect) return canvasFrac;

        final cropWidthFrac = canvasRatio / sourceAspect;
        final slack = 1.0 - cropWidthFrac;
        final cropXFrac = (slack / 2 + offsetFrac * cropWidthFrac).clamp(
          0.0,
          slack,
        );
        return cropXFrac + canvasFrac * cropWidthFrac;
    }
  }

  static double _windowEnergy(List<double> profile, double srcFrac) {
    final samples = profile.length;
    final start = ((srcFrac - _windowFraction) * samples).floor().clamp(
      0,
      samples - 1,
    );
    final end = ((srcFrac + _windowFraction) * samples).ceil().clamp(
      1,
      samples,
    );
    var sum = 0.0;
    for (var i = start; i < end; i++) {
      sum += profile[i];
    }
    return sum;
  }
}
