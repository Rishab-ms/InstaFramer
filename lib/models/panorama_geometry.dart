import 'dart:math' as math;

import 'enums.dart';

/// Where the source photo actually lands on the panorama canvas.
///
/// One source of truth for the compositing arithmetic `ImageProcessor`
/// performs in pixels: [PanoramaSeams] needs it to score candidate seams,
/// [PanoramaSpec.emptyTiles] needs it to find blank tiles, `PanoramaCanvas`
/// needs it to composite the live preview, and the editor needs it to bound
/// the seam slider. Those all carried independent copies of the same fit/fill
/// maths, which is exactly how a preview drifts out of sync with its export.
///
/// Positions are fractions, never pixels: **canvas fractions** run 0..1
/// left-to-right across the whole canvas, **source fractions** 0..1 across the
/// full source width.
///
/// Sign convention, uniform across both fit modes: a positive [cropOffsetX]
/// moves the *photo* to the right. In Fill that means the crop window moves
/// left, which is why [cropStart] subtracts the offset.
class PanoramaGeometry {
  /// Hard cap on the nudge, in tile widths, on top of whatever the framing
  /// physically allows. A full tile of travel already moves any subject clear
  /// of any seam, and a heavily-cropped Fill would otherwise offer a slider
  /// that swings the photo halfway across the canvas.
  static const double maxNudge = 0.5;

  final PanoramaFitMode fitMode;
  final int tileCount;

  /// The nudge that is actually applied, in tile widths. The requested offset
  /// clamped to ±[maxCropOffsetX]. `ImageProcessor` clamps the same way in
  /// pixels; exposing the clamped value is what lets the UI stop showing a
  /// slider position the render will never honour.
  final double cropOffsetX;

  /// Largest nudge with any visible effect, in tile widths. Zero when the
  /// photo already spans the canvas width. Fit at full zoom on a source at
  /// least as wide as the canvas, or Fill of a source no wider than the
  /// canvas, because there is nowhere left to slide.
  final double maxCropOffsetX;

  /// Canvas fraction of the photo's left and right edges. Fill always covers
  /// the canvas, so they are 0 and 1 there.
  final double photoStart;
  final double photoEnd;

  /// Source fraction of the visible crop window's left edge and its width. Fit
  /// crops nothing away, so they are 0 and 1 there.
  final double cropStart;
  final double cropWidth;

  /// The vertical nudge that is actually applied, in **canvas heights**, and
  /// the largest one with any effect. Both are 0 in Fit, deliberately: Fit
  /// crops nothing, so a vertical nudge there would only slide the photo
  /// between the top and bottom bars, which reads as a misaligned render
  /// rather than a composition choice. This control exists for Fill, where
  /// vertical position decides what gets *thrown away*.
  final double cropOffsetY;
  final double maxCropOffsetY;

  /// Source fraction of the visible crop window's top edge and its height.
  /// The vertical counterparts of [cropStart] and [cropWidth]. Fit keeps the
  /// whole source, so they are 0 and 1 there.
  final double cropTop;
  final double cropHeight;

  const PanoramaGeometry._({
    required this.fitMode,
    required this.tileCount,
    required this.cropOffsetX,
    required this.maxCropOffsetX,
    required this.photoStart,
    required this.photoEnd,
    required this.cropStart,
    required this.cropWidth,
    required this.cropOffsetY,
    required this.maxCropOffsetY,
    required this.cropTop,
    required this.cropHeight,
  });

  /// Resolves the geometry for one set of settings against one source shape.
  ///
  /// [cropOffsetX] is the *requested* nudge in tile widths; the result carries
  /// the clamped one.
  factory PanoramaGeometry.resolve({
    required PanoramaFitMode fitMode,
    required int tileCount,
    required double scale,
    required double cropOffsetX,
    required double sourceAspect,
    required double canvasRatio,
    double cropOffsetY = 0,
  }) {
    switch (fitMode) {
      case PanoramaFitMode.fit:
        // Contain-fit at `scale`, centred, nudged within the bars. This is
        // `_overlayScaledImage`'s geometry expressed as fractions.
        final photoSpan = scale * math.min(1.0, sourceAspect / canvasRatio);
        final maxOffsetFrac = _cappedOffsetFrac(
          (1.0 - photoSpan) / 2,
          tileCount,
        );
        final offsetFrac = (cropOffsetX / tileCount).clamp(
          -maxOffsetFrac,
          maxOffsetFrac,
        );
        return PanoramaGeometry._(
          fitMode: fitMode,
          tileCount: tileCount,
          cropOffsetX: offsetFrac * tileCount,
          maxCropOffsetX: maxOffsetFrac * tileCount,
          photoStart: 0.5 - photoSpan / 2 + offsetFrac,
          photoEnd: 0.5 + photoSpan / 2 + offsetFrac,
          cropStart: 0,
          cropWidth: 1,
          // Fit is vertically centred, always. See [cropOffsetY].
          cropOffsetY: 0,
          maxCropOffsetY: 0,
          cropTop: 0,
          cropHeight: 1,
        );

      case PanoramaFitMode.fill:
        // Cover-fit + crop, `_coverCropResize`'s geometry. When the canvas is
        // wider-aspect than the source (the common panorama case: canvasRatio
        // grows with tileCount, sourceAspect doesn't) the crop keeps the full
        // source width, so there is no horizontal travel at all.
        final cropWidth = math.min(1.0, canvasRatio / sourceAspect);
        final cropSlack = 1.0 - cropWidth;
        // The offset is a canvas fraction; the crop window lives in source
        // fractions, so the travel available on the canvas is the crop slack
        // measured in units of the crop window's own width.
        final maxOffsetFrac = _cappedOffsetFrac(
          cropWidth <= 0 ? 0.0 : cropSlack / 2 / cropWidth,
          tileCount,
        );
        final offsetFrac = (cropOffsetX / tileCount).clamp(
          -maxOffsetFrac,
          maxOffsetFrac,
        );

        // Vertical is the same derivation on the other axis. The canvas is
        // one tile tall, so a nudge in canvas heights needs no tile-count
        // division. That division exists on X only to keep a given slider
        // position meaning the same thing at every tile count.
        final cropHeight = math.min(1.0, sourceAspect / canvasRatio);
        final cropSlackY = 1.0 - cropHeight;
        final maxOffsetFracY = cropHeight <= 0
            ? 0.0
            : math.min(cropSlackY / 2 / cropHeight, maxNudge);
        final offsetFracY = cropOffsetY.clamp(-maxOffsetFracY, maxOffsetFracY);

        return PanoramaGeometry._(
          fitMode: fitMode,
          tileCount: tileCount,
          cropOffsetX: offsetFrac * tileCount,
          maxCropOffsetX: maxOffsetFrac * tileCount,
          photoStart: 0,
          photoEnd: 1,
          cropStart: cropSlack / 2 - offsetFrac * cropWidth,
          cropWidth: cropWidth,
          cropOffsetY: offsetFracY,
          maxCropOffsetY: maxOffsetFracY,
          cropTop: cropSlackY / 2 - offsetFracY * cropHeight,
          cropHeight: cropHeight,
        );
    }
  }

  /// Clamps physically-available travel (a canvas fraction) to [maxNudge],
  /// which is expressed in tile widths.
  static double _cappedOffsetFrac(double available, int tileCount) =>
      math.max(0.0, math.min(available, maxNudge / tileCount));

  /// Maps a canvas-fraction position into a source-fraction position.
  ///
  /// Returns null when the position falls in Fit's letterbox bars. There is
  /// no source content there at all.
  double? canvasToSource(double canvasFrac) {
    if (canvasFrac < photoStart || canvasFrac > photoEnd) return null;
    final span = photoEnd - photoStart;
    if (span <= 0) return null;
    return cropStart + (canvasFrac - photoStart) / span * cropWidth;
  }

  /// Magnitude of the vertical nudge that lands the **source's** own third
  /// lines on the **canvas's** third lines, or 0 when there is no vertical
  /// travel. Positive is the upper alignment; negate it for the lower.
  ///
  /// The two positions worth snapping to, because a photographer who framed
  /// a subject on a third gets it back on a third after the crop instead of
  /// somewhere arbitrary.
  ///
  /// Falls out of the crop arithmetic: putting source fraction 1/3 at canvas
  /// fraction 1/3 needs `cropTop == cropSlackY / 3`, and since
  /// `cropTop == cropSlackY / 2 - offset * cropHeight`, that is
  /// `offset == cropSlackY / (6 * cropHeight)`: exactly a third of the
  /// available travel whenever [maxNudge] isn't capping it, and correctly
  /// less than that when it is.
  double get thirdsCropOffsetY {
    if (maxCropOffsetY <= 0 || cropHeight <= 0) return 0;
    final cropSlackY = 1.0 - cropHeight;
    return math.min(cropSlackY / (6 * cropHeight), maxCropOffsetY);
  }

  /// Fraction of tile [index] (0-based) that the photo covers, 0..1.
  double tileCoverage(int index) {
    final tileStart = index / tileCount;
    final tileEnd = (index + 1) / tileCount;
    final overlap =
        math.min(tileEnd, photoEnd) - math.max(tileStart, photoStart);
    return (overlap * tileCount).clamp(0.0, 1.0);
  }

  /// 1-indexed tiles the photo barely reaches. Slides that would read as
  /// blank background in the carousel. See Smart Defaults B in the plan.
  List<int> emptyTiles({double threshold = 0.5}) {
    final empty = <int>[];
    for (var k = 0; k < tileCount; k++) {
      if (tileCoverage(k) < threshold) empty.add(k + 1);
    }
    return empty;
  }

  /// Coverage of the least-covered tile. How blank the emptiest slide is.
  ///
  /// The measure to compare framings by, where [emptyTiles] only counts them:
  /// two half-covered tiles and one full plus one blank both report "some
  /// tiles are empty", but the second is a carousel with a dead slide in it.
  double get minTileCoverage {
    var worst = 1.0;
    for (var k = 0; k < tileCount; k++) {
      worst = math.min(worst, tileCoverage(k));
    }
    return worst;
  }
}
