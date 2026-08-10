import 'package:flutter_test/flutter_test.dart';
import 'package:insta_upload_helper/models/enums.dart';
import 'package:insta_upload_helper/models/panorama_geometry.dart';

void main() {
  // Pure arithmetic, no binding, no isolate, no I/O.

  PanoramaGeometry fit({
    int tileCount = 2,
    double scale = 1.0,
    double cropOffsetX = 0,
    required double sourceAspect,
  }) => PanoramaGeometry.resolve(
    fitMode: PanoramaFitMode.fit,
    tileCount: tileCount,
    scale: scale,
    cropOffsetX: cropOffsetX,
    sourceAspect: sourceAspect,
    canvasRatio: tileCount * 0.8,
  );

  PanoramaGeometry fill({
    int tileCount = 2,
    double cropOffsetX = 0,
    required double sourceAspect,
  }) => PanoramaGeometry.resolve(
    fitMode: PanoramaFitMode.fill,
    tileCount: tileCount,
    scale: 1.0,
    cropOffsetX: cropOffsetX,
    sourceAspect: sourceAspect,
    canvasRatio: tileCount * 0.8,
  );

  group('Fit', () {
    test('centres the photo and reports the bars as having no source', () {
      // Source 1.6:1 at scale 0.8 into a 1.6:1 canvas. The photo spans 80% of
      // the canvas width, leaving a 10% bar each side.
      final geometry = fit(sourceAspect: 1.6, scale: 0.8);

      expect(geometry.photoStart, closeTo(0.1, 1e-9));
      expect(geometry.photoEnd, closeTo(0.9, 1e-9));
      expect(geometry.canvasToSource(0.5), closeTo(0.5, 1e-9));
      // Inside the left bar: no photo there to cut through.
      expect(geometry.canvasToSource(0.05), isNull);
      expect(geometry.canvasToSource(0.95), isNull);
    });

    test('clamps a requested nudge to the slack and reports it clamped', () {
      final geometry = fit(sourceAspect: 1.6, scale: 0.8, cropOffsetX: 5.0);

      // Slack is 10% of the canvas each way; 10% of a 1.6:1 canvas is 0.2 tile
      // widths at 2 tiles.
      expect(geometry.maxCropOffsetX, closeTo(0.2, 1e-9));
      expect(geometry.cropOffsetX, closeTo(0.2, 1e-9));
      // Clamped, so the photo's right edge lands exactly on the canvas edge,
      // never past it. This is the bug the preview used to show: an
      // unclamped nudge painted part of the photo outside the canvas, where
      // it was silently cropped away and replaced by a background bar the
      // export never rendered.
      expect(geometry.photoEnd, closeTo(1.0, 1e-9));
      expect(geometry.photoStart, closeTo(0.2, 1e-9));
    });

    test('has no travel once the photo spans the canvas width', () {
      // Source at least as wide-aspect as the canvas, at full zoom: the
      // contain-fit photo is exactly canvas-width, so there is no slack.
      expect(fit(sourceAspect: 1.6, scale: 1.0).maxCropOffsetX, 0);
      expect(fit(sourceAspect: 3.0, scale: 1.0).maxCropOffsetX, 0);
    });

    test('flags tiles the photo barely reaches', () {
      // 1.5:1 source into a 6-tile (4.8:1) canvas: the photo occupies the
      // middle ~31% of the canvas, so the outer tiles are background.
      final geometry = fit(tileCount: 6, sourceAspect: 1.5);
      expect(geometry.emptyTiles(), [1, 2, 5, 6]);

      // Comfortably-filled canvas: nothing empty.
      expect(fit(tileCount: 2, sourceAspect: 1.6).emptyTiles(), isEmpty);
    });
  });

  group('Fill', () {
    test('has no travel when the source is no wider than the canvas', () {
      // Cover-cropping a 1.6:1 source into a 1.6:1 canvas keeps the full
      // source width, so there is no crop window to slide.
      expect(fill(sourceAspect: 1.6).maxCropOffsetX, 0);
      expect(fill(sourceAspect: 1.3).maxCropOffsetX, 0);
    });

    test('slides the crop window when the source is wider than the canvas', () {
      // 3.2:1 source into a 1.6:1 canvas → half the source width is kept.
      final centred = fill(sourceAspect: 3.2);
      expect(centred.cropWidth, closeTo(0.5, 1e-9));
      expect(centred.cropStart, closeTo(0.25, 1e-9));
      expect(centred.photoStart, 0);
      expect(centred.photoEnd, 1);

      final nudged = fill(sourceAspect: 3.2, cropOffsetX: nudge);
      // Positive offset moves the *photo* right, which means taking the crop
      // from further left.
      expect(nudged.cropStart, lessThan(centred.cropStart));
    });

    test('clamps the crop window inside the source', () {
      final geometry = fill(sourceAspect: 3.2, cropOffsetX: -5.0);
      expect(geometry.cropStart + geometry.cropWidth, lessThanOrEqualTo(1.0));
      expect(geometry.cropStart, greaterThanOrEqualTo(0.0));
    });
  });

  group('Fill vertical crop', () {
    PanoramaGeometry fillY({
      int tileCount = 2,
      double cropOffsetY = 0,
      required double sourceAspect,
    }) => PanoramaGeometry.resolve(
      fitMode: PanoramaFitMode.fill,
      tileCount: tileCount,
      scale: 1.0,
      cropOffsetX: 0,
      cropOffsetY: cropOffsetY,
      sourceAspect: sourceAspect,
      canvasRatio: tileCount * 0.8,
    );

    test('has travel exactly when the canvas is wider than the source', () {
      // 1.2:1 source into a 1.6:1 canvas: covering the width means overflowing
      // the height, so the top and bottom get cropped and there is a band to
      // choose. This is the common panorama case, since canvasRatio grows with
      // tile count while the source's aspect does not.
      expect(fillY(sourceAspect: 1.2).maxCropOffsetY, greaterThan(0));

      // 3.2:1 source into the same canvas: the sides get cropped instead, the
      // full source height is kept, and there is nothing to move vertically.
      expect(fillY(sourceAspect: 3.2).maxCropOffsetY, 0);
    });

    test('a positive nudge moves the photo down, revealing the source top', () {
      final centred = fillY(sourceAspect: 1.2);
      final nudged = fillY(sourceAspect: 1.2, cropOffsetY: 0.05);

      // Moving the photo down means taking the crop from further up.
      expect(nudged.cropTop, lessThan(centred.cropTop));
      // Same convention as the horizontal nudge, which is the point, one
      // mental model for both axes.
      expect(
        fill(sourceAspect: 3.2, cropOffsetX: nudge).cropStart,
        lessThan(fill(sourceAspect: 3.2).cropStart),
      );
    });

    test('clamps the crop window inside the source', () {
      final geometry = fillY(sourceAspect: 1.2, cropOffsetY: 5.0);
      expect(geometry.cropTop, greaterThanOrEqualTo(0.0));
      expect(geometry.cropTop + geometry.cropHeight, lessThanOrEqualTo(1.0));
      expect(geometry.cropOffsetY, geometry.maxCropOffsetY);
    });

    test('the thirds offset lands the source thirds on the canvas thirds', () {
      // The whole point of the guide lines: a subject the photographer framed
      // on a third comes back on a third after the crop.
      final centred = fillY(sourceAspect: 1.2);
      final thirds = centred.thirdsCropOffsetY;
      expect(thirds, greaterThan(0));

      final upper = fillY(sourceAspect: 1.2, cropOffsetY: thirds);
      expect(
        upper.cropTop + (1 / 3) * upper.cropHeight,
        closeTo(1 / 3, 1e-9),
        reason: 'canvas 1/3 should be showing source 1/3',
      );

      final lower = fillY(sourceAspect: 1.2, cropOffsetY: -thirds);
      expect(
        lower.cropTop + (2 / 3) * lower.cropHeight,
        closeTo(2 / 3, 1e-9),
        reason: 'canvas 2/3 should be showing source 2/3',
      );
    });

    test('the thirds offset is a third of the travel while uncapped', () {
      final geometry = fillY(sourceAspect: 1.2);
      expect(
        geometry.thirdsCropOffsetY,
        closeTo(geometry.maxCropOffsetY / 3, 1e-9),
      );
    });

    test('the thirds offset stays reachable when maxNudge caps travel', () {
      // A narrow source across many tiles crops away so much height that the
      // physical travel exceeds the nudge cap. The thirds offset must still be
      // somewhere the slider can actually reach, even though it then stops
      // being exactly a third of the travel.
      final geometry = fillY(tileCount: 6, sourceAspect: 1.2);
      expect(geometry.maxCropOffsetY, PanoramaGeometry.maxNudge);
      expect(
        geometry.thirdsCropOffsetY,
        lessThanOrEqualTo(geometry.maxCropOffsetY),
      );
    });

    test('has no thirds offset to snap to when there is no travel', () {
      expect(fillY(sourceAspect: 3.2).thirdsCropOffsetY, 0);
    });
  });

  test('Fit stays vertically centred and offers no vertical travel', () {
    // Fit crops nothing, so a vertical nudge could only slide the photo
    // between its own bars. An asymmetry that reads as a misaligned render
    // rather than a composition choice. The geometry refuses it outright so
    // no caller has to remember the rule.
    final geometry = PanoramaGeometry.resolve(
      fitMode: PanoramaFitMode.fit,
      tileCount: 2,
      scale: 0.8,
      cropOffsetX: 0,
      cropOffsetY: 0.4,
      sourceAspect: 1.6,
      canvasRatio: 1.6,
    );

    expect(geometry.maxCropOffsetY, 0);
    expect(geometry.cropOffsetY, 0);
    expect(geometry.cropTop, 0);
    expect(geometry.cropHeight, 1);
  });

  test('a positive nudge moves the photo right in both fit modes', () {
    // The direction the slider means has to be the same in Fit and Fill, or
    // the control reverses under the user when they switch mode. Moving the
    // photo right means the canvas centre now samples further *left* in the
    // source, whichever way the renderer achieves it.
    final fitCentre = fit(sourceAspect: 1.6, scale: 0.8).canvasToSource(0.5)!;
    final fitNudged = fit(
      sourceAspect: 1.6,
      scale: 0.8,
      cropOffsetX: nudge,
    ).canvasToSource(0.5)!;
    expect(fitNudged, lessThan(fitCentre));

    final fillCentre = fill(sourceAspect: 3.2).canvasToSource(0.5)!;
    final fillNudged = fill(
      sourceAspect: 3.2,
      cropOffsetX: nudge,
    ).canvasToSource(0.5)!;
    expect(fillNudged, lessThan(fillCentre));
  });
}

/// A nudge small enough to sit inside the travel every case here allows.
const double nudge = 0.05;
