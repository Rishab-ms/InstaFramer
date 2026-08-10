import 'package:flutter_test/flutter_test.dart';
import 'package:insta_upload_helper/models/enums.dart';
import 'package:insta_upload_helper/models/panorama_geometry.dart';
import 'package:insta_upload_helper/models/panorama_seams.dart';

void main() {
  const samples = 600;

  /// A profile that is [background] everywhere except a narrow spike of 1.0
  /// centred on source fraction [at] — a single hard vertical edge (a pole, a
  /// building corner, a person) in an otherwise quiet photo.
  List<double> spikeAt(double at, {double background = 0.05}) {
    final profile = List<double>.filled(samples, background);
    final centre = (at * samples).round();
    for (var i = centre - 6; i <= centre + 6; i++) {
      if (i >= 0 && i < samples) profile[i] = 1.0;
    }
    return profile;
  }

  /// Busy on the left, quiet on the right — the shape that tempts an
  /// unconstrained search to shove the photo as far as it will go.
  List<double> rampDown() =>
      List<double>.generate(samples, (i) => 1.0 - i / (samples - 1));

  double best({
    required List<double> profile,
    int tileCount = 2,
    double scale = 1.0,
    double sourceAspect = 1.6,
    PanoramaFitMode fitMode = PanoramaFitMode.fit,
  }) => PanoramaSeams.bestSeamOffset(
    energyProfile: profile,
    tileCount: tileCount,
    fitMode: fitMode,
    scale: scale,
    sourceAspect: sourceAspect,
    canvasRatio: tileCount * 0.8,
  );

  PanoramaGeometry geometryFor(
    double offset, {
    int tileCount = 2,
    double scale = 1.0,
    double sourceAspect = 1.6,
    PanoramaFitMode fitMode = PanoramaFitMode.fit,
  }) => PanoramaGeometry.resolve(
    fitMode: fitMode,
    tileCount: tileCount,
    scale: scale,
    cropOffsetX: offset,
    sourceAspect: sourceAspect,
    canvasRatio: tileCount * 0.8,
  );

  group('bestSeamOffset stays centred unless moving earns it', () {
    test('returns 0 for a featureless photo', () {
      expect(best(profile: List<double>.filled(samples, 0.4), scale: 0.8), 0);
    });

    test('returns 0 with no energy profile at all', () {
      // Thumbnail read or decode failed — centred is the honest default.
      expect(best(profile: const [], scale: 0.8), 0);
    });

    test('returns 0 when the photo already spans the canvas', () {
      // Full zoom on a source at least as wide-aspect as the canvas: there is
      // nowhere to slide, so any non-zero answer would be a slider position
      // the render cannot honour.
      expect(best(profile: rampDown(), scale: 1.0, sourceAspect: 1.6), 0);
    });

    test('returns 0 when the gain over centred framing is marginal', () {
      // A shallow bump rather than a hard edge: moving the photo off centre
      // buys almost nothing, and a surprising framing costs more than the
      // seam does.
      final profile = List<double>.filled(samples, 0.5);
      for (var i = 290; i < 310; i++) {
        profile[i] = 0.55;
      }
      expect(best(profile: profile, scale: 0.8), 0);
    });
  });

  group('bestSeamOffset never returns an unreachable offset', () {
    test('stays inside the travel the framing allows', () {
      // Regression for the reported bug: the sweep used to span a nominal
      // ±0.5 tile while the renderer clamped to the slack, so every
      // over-range candidate scored identically and the first one scanned —
      // the hard-left extreme — won on a tie and was stored as -50%. The
      // photo then jumped to the canvas edge with a quarter of it hanging
      // off, behind a background bar the export never produced.
      for (final scale in [0.5, 0.7, 0.92, 1.0]) {
        for (final tileCount in [2, 3, 4]) {
          final offset = best(
            profile: rampDown(),
            tileCount: tileCount,
            scale: scale,
          );
          final maxOffset = geometryFor(
            0,
            tileCount: tileCount,
            scale: scale,
          ).maxCropOffsetX;

          expect(
            offset.abs(),
            lessThanOrEqualTo(maxOffset + 1e-9),
            reason: 'scale $scale, $tileCount tiles',
          );
        }
      }
    });

    test('at 2 tiles and 92% zoom it can only move a few percent', () {
      // The exact framing from the bug report. A 1.6:1 source at 92% zoom has
      // 4% of the canvas of slack each way, i.e. 0.08 tile widths.
      final offset = best(profile: rampDown(), scale: 0.92);
      expect(offset.abs(), lessThanOrEqualTo(0.08 + 1e-9));
    });
  });

  group('bestSeamOffset moves the seam off a hard edge', () {
    test('shifts away from an edge sitting on the centred seam', () {
      // Photo spans 80% of the canvas, so the single seam at canvas 0.5 maps
      // to source 0.5 when centred — right through the spike.
      final profile = spikeAt(0.5);
      final offset = best(profile: profile, scale: 0.8);

      expect(offset, isNot(0));

      // The seam should land on quiet source, not merely somewhere else.
      final seamSource = geometryFor(offset, scale: 0.8).canvasToSource(0.5)!;
      expect(profile[(seamSource * samples).round()], lessThan(0.1));
    });

    test('leaves a seam that is already clear where it is', () {
      // The spike sits far from where any seam falls, so centred is already
      // optimal and there is nothing to gain by moving.
      expect(best(profile: spikeAt(0.05), scale: 0.8), 0);
    });
  });

  test('bestSeamOffset never empties a tile to quiet a seam', () {
    // A seam parked in Fit's background bars cuts through nothing and so
    // scores zero — which means an unconstrained search is rewarded for
    // shoving the photo into a corner until a whole carousel slide is blank.
    //
    // Framing: 2 tiles, photo spanning 60% of the canvas. Centred, both tiles
    // are 60% covered; at the far end of the travel the leading tile drops to
    // 20% — a slide that is mostly background.
    const scale = 0.6;
    final centred = geometryFor(0, scale: scale);
    expect(centred.emptyTiles(), isEmpty);
    expect(
      geometryFor(centred.maxCropOffsetX, scale: scale).emptyTiles(),
      isNotEmpty,
      reason: 'the framing under test must actually be able to empty a tile',
    );

    // All the quiet source is at the right-hand end, reachable only by
    // sliding the photo hard left.
    final offset = best(profile: rampDown(), scale: scale);

    expect(geometryFor(offset, scale: scale).emptyTiles(), isEmpty);
  });

  test('bestSeamOffset does not exploit an already-under-covered framing', () {
    // Regression: counting empty tiles instead of measuring them let a bad
    // framing justify a worse one. Zoomed out to 50%, a 1.5:1 source covers
    // only ~47% of each of its two tiles, so *both* already count as empty —
    // and sliding the photo hard left, which parks the seam in the background
    // bar for a free score of zero, drops the count from two to one and
    // registered as an improvement. The result was a photo jammed against the
    // left edge with an entirely blank second slide.
    const scale = 0.5;
    const aspect = 1.5;
    final centred = geometryFor(0, scale: scale, sourceAspect: aspect);
    expect(
      centred.emptyTiles().length,
      2,
      reason: 'the framing under test must start with both tiles under-covered',
    );

    final offset = best(
      profile: rampDown(),
      scale: scale,
      sourceAspect: aspect,
    );
    final result = geometryFor(offset, scale: scale, sourceAspect: aspect);

    // No slide may end up blanker than it already was.
    expect(
      result.minTileCoverage,
      greaterThanOrEqualTo(centred.minTileCoverage - 1e-9),
    );
  });

  group('cleanerTileCount', () {
    int? cleaner({
      required List<double> profile,
      int currentTileCount = 2,
      int maxTiles = 6,
      double sourceAspect = 1.5,
    }) => PanoramaSeams.cleanerTileCount(
      energyProfile: profile,
      currentTileCount: currentTileCount,
      maxTiles: maxTiles,
      fitMode: PanoramaFitMode.fit,
      scale: 1.0,
      sourceAspect: sourceAspect,
      tileRatio: 0.8,
    );

    test('offers an odd count when a subject sits dead centre', () {
      // The case zoom cannot fix. Every even tile count has a seam at canvas
      // 0.5, and scaling about the canvas centre leaves the centre a fixed
      // point — so at 4 tiles a centred subject is cut at every zoom level.
      // Only a different tile count moves that cut.
      final suggestion = cleaner(
        profile: spikeAt(0.5),
        currentTileCount: 4,
        sourceAspect: 3.0,
      );

      expect(suggestion, isNotNull);
      expect(
        suggestion!.isOdd,
        isTrue,
        reason: 'even counts keep a seam pinned on the centred subject',
      );
    });

    test('stays quiet when the current count already cuts cleanly', () {
      // At 3 tiles the seams fall at roughly source 0.33 and 0.67 — already
      // clear of a centred subject, so there is nothing to advise.
      expect(
        cleaner(profile: spikeAt(0.5), currentTileCount: 3, sourceAspect: 3.0),
        isNull,
      );
    });

    test('stays quiet on a featureless photo', () {
      expect(cleaner(profile: List<double>.filled(samples, 0.4)), isNull);
    });

    test('stays quiet with no energy profile at all', () {
      expect(cleaner(profile: const []), isNull);
    });

    test('stays quiet when every alternative would blank a slide', () {
      // A 3:2 source is the awkward case: 2 tiles is a 1.6:1 canvas it nearly
      // fills, while 3 tiles is a 2.4:1 canvas it only reaches 62% across, so
      // the outer slides drop under the empty-tile threshold. The subject is
      // dead centre and gets cut, and there is genuinely nothing better to
      // offer — so the advice stays silent rather than trading one visible
      // defect for a worse one.
      expect(cleaner(profile: spikeAt(0.5), sourceAspect: 1.5), isNull);
    });

    test('never advises a count that would leave a slide mostly blank', () {
      final suggestion = cleaner(
        profile: spikeAt(0.5),
        currentTileCount: 4,
        maxTiles: 8,
        sourceAspect: 3.0,
      );

      expect(suggestion, isNotNull);
      final geometry = PanoramaGeometry.resolve(
        fitMode: PanoramaFitMode.fit,
        tileCount: suggestion!,
        scale: 1.0,
        cropOffsetX: 0,
        sourceAspect: 3.0,
        canvasRatio: suggestion * 0.8,
      );
      expect(geometry.emptyTiles(), isEmpty);
    });
  });

  test('bestSeamOffset optimises Fill through the crop window', () {
    // 3.2:1 source cover-cropped into a 1.6:1 canvas: half the source width
    // is kept, and the seam at canvas 0.5 maps to source 0.5 when centred.
    final profile = spikeAt(0.5);
    final offset = best(
      profile: profile,
      fitMode: PanoramaFitMode.fill,
      sourceAspect: 3.2,
    );

    expect(offset, isNot(0));

    final seamSource = geometryFor(
      offset,
      fitMode: PanoramaFitMode.fill,
      sourceAspect: 3.2,
    ).canvasToSource(0.5)!;
    expect(profile[(seamSource * samples).round()], lessThan(0.1));
  });
}
