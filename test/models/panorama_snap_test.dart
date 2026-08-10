import 'package:flutter_test/flutter_test.dart';
import 'package:insta_upload_helper/models/enums.dart';
import 'package:insta_upload_helper/models/panorama_geometry.dart';
import 'package:insta_upload_helper/models/panorama_spec.dart';

void main() {
  // A 1.2:1 source into a 1.6:1 canvas: the cover fit crops top and bottom, so
  // there is a vertical band to choose and snap points to choose it against.
  const sourceAspect = 1.2;
  const tileCount = 2;
  const canvasRatio = tileCount * 0.8;

  double snap(double value) => PanoramaSpec.snapCropOffsetY(
    value,
    tileCount: tileCount,
    fitMode: PanoramaFitMode.fill,
    sourceAspect: sourceAspect,
    canvasRatio: canvasRatio,
  );

  final geometry = PanoramaGeometry.resolve(
    fitMode: PanoramaFitMode.fill,
    tileCount: tileCount,
    scale: 1.0,
    cropOffsetX: 0,
    sourceAspect: sourceAspect,
    canvasRatio: canvasRatio,
  );
  final maxOffset = geometry.maxCropOffsetY;
  final thirds = geometry.thirdsCropOffsetY;

  test('snaps to centre and to both thirds', () {
    expect(snap(maxOffset * 0.01), 0);
    expect(snap(thirds + maxOffset * 0.02), thirds);
    expect(snap(-thirds - maxOffset * 0.02), -thirds);
  });

  test('leaves values between the snap points alone', () {
    // Magnetic, not stepped — fine placement has to stay possible, or the
    // control stops doing what it is told.
    final between = (thirds + maxOffset) / 2;
    expect(snap(between), between);
    expect(snap(thirds / 2), thirds / 2);
  });

  test('lets go just outside the catch radius', () {
    // The boundary is the whole behaviour: inside it the control assists,
    // outside it the control obeys. A snap that reaches too far reads as a
    // slider that won't sit where you put it.
    const radiusFraction = 0.06;
    final justInside = maxOffset * radiusFraction * 0.9;
    final justOutside = maxOffset * radiusFraction * 1.1;

    expect(snap(justInside), 0);
    expect(snap(justOutside), justOutside);
  });

  test('returns centred when the framing has no vertical travel', () {
    // A source wider-aspect than the canvas is cropped at the sides instead,
    // so there is no band to choose and nothing to snap to.
    expect(
      PanoramaSpec.snapCropOffsetY(
        0.3,
        tileCount: tileCount,
        fitMode: PanoramaFitMode.fill,
        sourceAspect: 3.2,
        canvasRatio: canvasRatio,
      ),
      0,
    );
  });

  test('returns centred in Fit, which has no vertical travel at all', () {
    expect(
      PanoramaSpec.snapCropOffsetY(
        0.3,
        tileCount: tileCount,
        fitMode: PanoramaFitMode.fit,
        sourceAspect: sourceAspect,
        canvasRatio: canvasRatio,
      ),
      0,
    );
  });
}
