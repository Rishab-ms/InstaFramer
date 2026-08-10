import 'dart:math' as math;

import 'enums.dart';
import 'panorama_geometry.dart';
import 'panorama_spec.dart';

/// Automatic seam placement — **built, kept, and deliberately not wired up.**
///
/// ⚠️ Nothing calls this. `PanoramaBloc` opens every photo centred on both
/// axes and leaves positioning entirely to the user's own dragging, and
/// `ImageProcessor.computeEdgeEnergyProfile` — the input this needs — is no
/// longer computed at pick time. Read this note before reconnecting any of it.
///
/// **Why it is off.** The product reason outranks the algorithm. An
/// auto-chosen offset moves the photo off centre with uneven background bars
/// on the very first frame the user sees. That reads as a rendering fault, not
/// a considered choice — and it is spent solving a problem the user has not
/// gone looking for yet. A tool that quietly repositions your photo before you
/// have touched anything is harder to trust than one that hands it to you
/// centred and gets out of the way. The measurable win at the seam was never
/// worth the unprompted asymmetry, and no amount of tuning inside this file
/// changes that trade.
///
/// It also earns very little now: panoramas open at full zoom
/// (`PanoramaSettings.defaultScale`), which leaves only a few percent of the
/// canvas as slack, so on a typical source there is barely anywhere to move
/// the photo to.
///
/// **Why keep it.** The geometry, scoring and guard rails are correct and
/// tested (`test/models/panorama_seams_test.dart`), and the failure modes they
/// encode — unreachable offsets, ties resolving to an extreme, quieting a seam
/// by emptying a slide — are traps any future attempt would fall into again.
/// If automatic positioning ever returns it should be *offered*, on request,
/// against a framing the user already chose — never applied to an opening
/// state.
///

/// Seams sit at fixed spacing (one per tile boundary), so there is exactly
/// one free parameter — the horizontal offset — which makes good seam
/// placement a 1-D minimization rather than a vision problem. Pure Dart, no
/// isolate: the expensive part (decoding the photo and computing the energy
/// profile) already happened once via `ImageProcessor.computeEdgeEnergyProfile`
/// — re-optimizing over that cached ~600-element array costs microseconds,
/// cheap enough to re-run on every tile-count, zoom or fit-mode change.
///
/// The search is deliberately conservative, because a *surprising* framing is
/// a worse failure than a merely adequate seam. Three rules enforce that:
///
/// 1. **Only reachable offsets are considered.** The sweep spans the travel
///    [PanoramaGeometry] actually allows, not a nominal ±0.5 tile. Sweeping
///    past the clamp made every over-range candidate score identically, so the
///    first one scanned — the hard-left extreme — won on a tie and got stored
///    as the user-visible slider value.
/// 2. **Centre wins ties, and near-ties.** Offsets are only preferred over
///    centre when they beat it by [_minRelativeGain]; among candidates within
///    [_tieTolerance] of the best, the one closest to centre wins.
/// 3. **Never empty a tile to quiet a seam.** A seam parked in Fit's
///    background bars scores zero, so an unconstrained search is actively
///    rewarded for shoving the photo into a corner until a whole slide is
///    blank. Candidates that leave any tile less covered than
///    [_minTileCoverage] — or than centred framing already does, whichever is
///    lower — are rejected outright.
class PanoramaSeams {
  const PanoramaSeams._();

  /// Half-width of the energy window scored around each candidate seam, as a
  /// fraction of source width.
  ///
  /// This is a clearance band, not a hit test: because the centring rules pull
  /// the result back to the *smallest* move that quiets a seam, the window
  /// half-width is exactly how much room the seam ends up leaving around the
  /// edge it dodged. At 1% the seam settled a couple of percent from a face or
  /// a pole — technically clear, visibly close.
  static const double _windowFraction = 0.02;

  /// How much better than centred framing a candidate must be before the photo
  /// is moved off centre at all, as a fraction of the centred seam energy.
  static const double _minRelativeGain = 0.15;

  /// Candidates within this fraction of the running best count as a tie, and
  /// ties resolve toward centre.
  static const double _tieTolerance = 0.02;

  /// No candidate may leave a tile covered less than this. Matches the
  /// empty-tile threshold the editor warns at, so automatic placement can
  /// never produce the state the UI immediately complains about.
  static const double _minTileCoverage = 0.5;

  /// How much quieter another tile count's seams must be before it is worth
  /// suggesting — see [cleanerTileCount]. Twice [_minRelativeGain], because
  /// changing tile count changes how many slides get posted, which is a far
  /// bigger ask than shifting the photo a few percent.
  static const double _minTileCountGain = 0.30;

  /// Sweeps the reachable seam offsets and returns the one that best keeps the
  /// interior seams out of faces, poles and building edges — or 0 when no
  /// candidate is a clear enough improvement on simply centring the photo.
  ///
  /// [energyProfile] is normalised 0..1 across the **full source width**
  /// (see `ImageProcessor.computeEdgeEnergyProfile`); the remaining parameters
  /// describe the render exactly as `ImageProcessor` will composite it, since
  /// scoring a candidate requires mapping each canvas-coordinate seam back
  /// into source coordinates.
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

    PanoramaGeometry geometryAt(double offset) => PanoramaGeometry.resolve(
      fitMode: fitMode,
      tileCount: tileCount,
      scale: scale,
      cropOffsetX: offset,
      sourceAspect: sourceAspect,
      canvasRatio: canvasRatio,
    );

    final centred = geometryAt(0);
    final maxOffset = centred.maxCropOffsetX;
    // The photo already spans the canvas width — there is nothing to slide,
    // and reporting anything but 0 would put the slider somewhere the render
    // can't follow.
    if (maxOffset <= 0) return 0;

    final centredEnergy = _seamEnergy(centred, energyProfile);
    // No tile may end up emptier than this. Normally the 50% empty-tile
    // threshold; when the framing is *already* under it (a zoomed-out photo
    // that doesn't reach across its tiles) the centred coverage becomes the
    // bar instead, so a bad starting point can't be used to justify a worse
    // one.
    final minCoverage = math.min(_minTileCoverage, centred.minTileCoverage);

    var bestOffset = 0.0;
    var bestEnergy = centredEnergy;

    for (var step = 0; step <= steps; step++) {
      final candidate = -maxOffset + step * (2 * maxOffset / steps);
      final geometry = geometryAt(candidate);

      // Rule 3: a quieter cut isn't worth a blank slide.
      if (geometry.minTileCoverage < minCoverage) continue;

      final energy = _seamEnergy(geometry, energyProfile);
      // Rule 2: strictly better, or an effective tie that sits closer to
      // centre. bestOffset starts at 0, so the tie branch can only ever pull
      // the result back toward centre, never away from it.
      final isBetter = energy < bestEnergy * (1 - _tieTolerance);
      final isCentringTie =
          energy <= bestEnergy * (1 + _tieTolerance) &&
          candidate.abs() < bestOffset.abs();
      if (isBetter || isCentringTie) {
        bestEnergy = math.min(bestEnergy, energy);
        bestOffset = candidate;
      }
    }

    // Rule 2, the hard floor: off-centre framing has to earn its place.
    if (bestEnergy > centredEnergy * (1 - _minRelativeGain)) return 0;
    return bestOffset;
  }

  /// A tile count whose seams would fall on markedly quieter source than the
  /// current one, or null when the current count is already as good as it gets.
  ///
  /// The symmetric alternative to nudging. Zoom cannot help here — scaling
  /// happens about the canvas centre, so the centre is a fixed point and every
  /// even tile count has a seam pinned there regardless of zoom — and the
  /// nudge buys a better cut at the cost of visibly uneven bars. Changing the
  /// tile count moves every seam, keeps the photo full size, and keeps the
  /// framing symmetric.
  ///
  /// Scored at a **centred** offset, deliberately: this is advice about how
  /// many slides the photo wants, and folding in the fine-tuning nudge would
  /// make the recommendation flicker as the user drags an unrelated slider.
  /// Mirrors `PanoramaSpec.suggestedTileCount`, which ignores the nudge for
  /// the same reason.
  ///
  /// Returned as advice for the UI to offer, never applied automatically:
  /// tile count decides how many slides get posted, which is the user's call.
  static int? cleanerTileCount({
    required List<double> energyProfile,
    required int currentTileCount,
    required int maxTiles,
    required PanoramaFitMode fitMode,
    required double scale,
    required double sourceAspect,
    required double tileRatio,
  }) {
    if (energyProfile.isEmpty) return null;

    /// Null for a count that would leave a slide mostly blank — advising a
    /// framing the empty-tile warning immediately flags would be incoherent.
    double? energyAt(int tileCount) {
      final geometry = PanoramaGeometry.resolve(
        fitMode: fitMode,
        tileCount: tileCount,
        scale: scale,
        cropOffsetX: 0,
        sourceAspect: sourceAspect,
        canvasRatio: PanoramaSpec.canvasRatio(tileCount, tileRatio),
      );
      if (geometry.minTileCoverage < _minTileCoverage) return null;
      return _seamEnergy(geometry, energyProfile);
    }

    final currentEnergy = energyAt(currentTileCount);
    // The current count already has a blank slide; the empty-tile warning owns
    // that case and gives its own advice.
    if (currentEnergy == null) return null;

    final threshold = currentEnergy * (1 - _minTileCountGain);
    int? best;
    var bestEnergy = double.infinity;

    for (var count = PanoramaSpec.minTiles; count <= maxTiles; count++) {
      if (count == currentTileCount) continue;
      final energy = energyAt(count);
      if (energy == null || energy > threshold) continue;

      // Among counts that clear the bar, prefer the genuinely quietest, and on
      // an effective tie the smallest change from what the user already has —
      // this is advice about a change, so it should ask for the least one.
      final isBetter = energy < bestEnergy * (1 - _tieTolerance);
      final isSmallerChange =
          best != null &&
          energy <= bestEnergy * (1 + _tieTolerance) &&
          (count - currentTileCount).abs() < (best - currentTileCount).abs();
      if (best == null || isBetter || isSmallerChange) {
        bestEnergy = math.min(bestEnergy, energy);
        best = count;
      }
    }

    return best;
  }

  /// Mean energy across the interior seams of [geometry].
  ///
  /// Averaged rather than summed so the number stays comparable across tile
  /// counts — the relative thresholds above are meaningless against a total
  /// that grows with the number of seams.
  static double _seamEnergy(
    PanoramaGeometry geometry,
    List<double> energyProfile,
  ) {
    var total = 0.0;
    for (var i = 1; i < geometry.tileCount; i++) {
      final srcFrac = geometry.canvasToSource(i / geometry.tileCount);
      // A seam landing in Fit's letterbox bars cuts through nothing, so it
      // contributes zero. Safe only because the empty-tile rule above stops
      // the search from manufacturing bars to exploit it.
      if (srcFrac == null) continue;
      total += _windowEnergy(energyProfile, srcFrac);
    }
    return total / (geometry.tileCount - 1);
  }

  /// Energy in a ±[_windowFraction] window around a seam, as an even blend of
  /// the window's peak and its mean.
  ///
  /// The peak is what actually decides a seam — it either severs a hard edge
  /// or it doesn't, and one strong column is enough to ruin it. The mean stops
  /// a uniformly busy neighbourhood (foliage, a crowd) from scoring as well as
  /// a genuinely clean one that happens to contain a single spike. Summing the
  /// window, as this did before, let a wide soft gradient outweigh a single
  /// hard edge — the opposite of what the eye notices at a slide boundary.
  static double _windowEnergy(List<double> profile, double srcFrac) {
    final samples = profile.length;
    final start = ((srcFrac - _windowFraction) * samples).floor().clamp(
      0,
      samples - 1,
    );
    final end = ((srcFrac + _windowFraction) * samples).ceil().clamp(
      start + 1,
      samples,
    );
    var sum = 0.0;
    var peak = 0.0;
    for (var i = start; i < end; i++) {
      sum += profile[i];
      if (profile[i] > peak) peak = profile[i];
    }
    return 0.5 * peak + 0.5 * (sum / (end - start));
  }
}
