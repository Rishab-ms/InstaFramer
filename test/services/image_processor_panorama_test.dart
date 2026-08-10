import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:insta_upload_helper/models/enums.dart';
import 'package:insta_upload_helper/models/panorama_settings.dart';
import 'package:insta_upload_helper/services/image_processor.dart';

void main() {
  // processPanorama uses compute(), which needs the binding initialised.
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Builds a [w]x[h] JPEG whose colour varies along the X axis only.
  ///
  /// Why a gradient and not a solid colour: these tests assert that a seam
  /// nudge does (or does not) move the photo horizontally, by comparing the
  /// encoded bytes of a tile before and after the nudge. On a solid-colour
  /// source every column is identical, so a horizontal shift produces byte
  /// identical output and the assertions would pass whether or not the offset
  /// was actually applied — a test that can't fail. A left-to-right gradient
  /// makes every column distinct, so any real shift changes the tile's pixels
  /// and therefore its bytes.
  ///
  /// The colour ramp is red rising 0->255 across the width while blue falls
  /// 255->0, with green pinned at 128. Both channels move so the gradient stays
  /// distinguishable after JPEG's chroma subsampling; the constant green just
  /// keeps overall brightness even, which stops the encoder from spending
  /// wildly different numbers of bytes on different tiles.
  ///
  /// The ramp is deliberately vertical-invariant (every row identical). That
  /// isolates the axis under test: a vertical crop difference cannot masquerade
  /// as a horizontal shift, so a byte difference means the X offset moved.
  Uint8List gradientSource(int w, int h) {
    final image = img.Image(width: w, height: h);
    for (var x = 0; x < w; x++) {
      // Map this column's position across the full width onto 0..255.
      final ramp = (255 * x / (w - 1)).round();
      for (var y = 0; y < h; y++) {
        image.setPixelRgb(x, y, ramp, 128, 255 - ramp);
      }
    }
    return img.encodeJpg(image);
  }

  final processor = ImageProcessor();

  group('processPanorama', () {
    test(
      'slices into exact 4:5 tiles in every fit mode and background',
      () async {
        // Aspect 3.2, which is exactly the 4-tile canvas ratio (4 * 0.8).
        final source = gradientSource(4000, 1250);

        for (final fitMode in PanoramaFitMode.values) {
          for (final background in [
            BackgroundType.white,
            BackgroundType.black,
            BackgroundType.extendedBlur,
          ]) {
            final tiles = await processor.processPanorama(
              source,
              PanoramaSettings(
                tileCount: 4,
                fitMode: fitMode,
                backgroundType: background,
                cropOffsetX: 0.4,
              ),
            );

            expect(tiles.length, 4);
            for (final tile in tiles) {
              final decoded = img.decodeImage(tile)!;
              // The canvas width is an exact multiple of tileWidth, so every tile
              // must come out at full size — a short final tile would mean the
              // slice arithmetic drifted.
              expect(decoded.width, 1080, reason: '$fitMode / $background');
              expect(decoded.height, 1350, reason: '$fitMode / $background');
            }
          }
        }
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Fit bounds the seam nudge to the slack inside the bars',
      () async {
        final source = gradientSource(4000, 1250);

        Future<List<Uint8List>> render(double scale, double cropOffsetX) =>
            processor.processPanorama(
              source,
              PanoramaSettings(
                tileCount: 4,
                scale: scale,
                cropOffsetX: cropOffsetX,
              ),
            );

        // At scale 1.0 the photo spans the full canvas width, so there is no
        // slack. Fit promises nothing is cropped, so the nudge must be a no-op
        // rather than pushing content off the edge.
        expect(await render(1.0, 0.4), equals(await render(1.0, 0.0)));

        // At scale 0.8 there are bars to slide within, so the nudge must apply.
        expect(await render(0.8, 0.4), isNot(equals(await render(0.8, 0.0))));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'Fill nudges only when the source is wider than the canvas',
      () async {
        // Source aspect 3.2 == the 4-tile canvas aspect, so the cover crop keeps
        // the full source width and there is no horizontal slack to nudge into.
        final exact = gradientSource(4000, 1250);
        final tight0 = await processor.processPanorama(
          exact,
          const PanoramaSettings(tileCount: 4, fitMode: PanoramaFitMode.fill),
        );
        final tight4 = await processor.processPanorama(
          exact,
          const PanoramaSettings(
            tileCount: 4,
            fitMode: PanoramaFitMode.fill,
            cropOffsetX: 0.4,
          ),
        );
        expect(tight4, equals(tight0));

        // Source aspect 4.8 into the same 3.2 canvas: the sides get cropped, so
        // there is slack and the nudge shifts the crop window.
        final wide = gradientSource(6000, 1250);
        final wide0 = await processor.processPanorama(
          wide,
          const PanoramaSettings(tileCount: 4, fitMode: PanoramaFitMode.fill),
        );
        final wide4 = await processor.processPanorama(
          wide,
          const PanoramaSettings(
            tileCount: 4,
            fitMode: PanoramaFitMode.fill,
            cropOffsetX: 0.4,
          ),
        );
        expect(wide4, isNot(equals(wide0)));

        // The nudge must not shrink the last tile by running the crop window off
        // the source edge — that is what the clamp in _coverCropResize prevents.
        expect(img.decodeImage(wide4.last)!.width, 1080);
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  test(
    'Fill nudges the crop vertically only when top/bottom are cropped',
    () async {
      /// Top-to-bottom gradient — the vertical counterpart of [gradientSource],
      /// for the same reason: every row has to be distinct or a vertical shift
      /// produces byte-identical output and the assertion can't fail.
      Uint8List verticalGradient(int w, int h) {
        final image = img.Image(width: w, height: h);
        for (var y = 0; y < h; y++) {
          final ramp = (255 * y / (h - 1)).round();
          for (var x = 0; x < w; x++) {
            image.setPixelRgb(x, y, ramp, 128, 255 - ramp);
          }
        }
        return img.encodeJpg(image);
      }

      Future<List<Uint8List>> render(Uint8List source, double cropOffsetY) =>
          processor.processPanorama(
            source,
            PanoramaSettings(
              tileCount: 4,
              fitMode: PanoramaFitMode.fill,
              cropOffsetY: cropOffsetY,
            ),
          );

      // Source aspect 2.0 into a 3.2:1 canvas: covering the width overflows the
      // height, so top and bottom are cropped and there is a band to choose.
      final tall = verticalGradient(4000, 2000);
      expect(await render(tall, 0.2), isNot(equals(await render(tall, 0.0))));

      // Source aspect 4.8 into the same canvas: the sides get cropped instead,
      // the full source height is kept, and the vertical nudge must be a no-op
      // rather than pushing the crop window off the source.
      final wide = verticalGradient(6000, 1250);
      expect(await render(wide, 0.2), equals(await render(wide, 0.0)));

      // The nudge must never shrink a tile by running the window past the edge.
      final extreme = await render(tall, 5.0);
      expect(img.decodeImage(extreme.first)!.height, 1350);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  group('computeEdgeEnergyProfile', () {
    /// A flat grey frame with two identical black vertical bars: one crossing
    /// only the top band of rows, one crossing only the middle band.
    ///
    /// Same width, same contrast, same number of rows each — so an unweighted
    /// column sum scores them identically, and any difference in the resulting
    /// profile is the row weighting alone. PNG, not JPEG: the point is a clean
    /// edge signal, and chroma subsampling would smear both bars by an amount
    /// that depends on where they sit.
    Uint8List twoBars({required int w, required int h}) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(128, 128, 128));

      void bar(int centreX, int startY, int endY) {
        for (var x = centreX - 3; x <= centreX + 3; x++) {
          for (var y = startY; y < endY; y++) {
            image.setPixelRgb(x, y, 0, 0, 0);
          }
        }
      }

      final band = h ~/ 5;
      bar(w ~/ 4, 0, band); // top of frame
      bar(3 * w ~/ 4, (h - band) ~/ 2, (h + band) ~/ 2); // centre of frame
      return img.encodePng(image);
    }

    /// Peak profile value near source fraction [at].
    ///
    /// A window, not a point sample: a bar's *interior* has black on both
    /// sides and therefore zero horizontal gradient, so all its energy sits in
    /// two narrow spikes at its edges. `PanoramaSeams` reads the profile
    /// through a window for the same reason.
    double peakNear(List<double> profile, double at) {
      final centre = (at * profile.length).round();
      final start = math.max(0, centre - 10);
      final end = math.min(profile.length, centre + 11);
      return profile.sublist(start, end).reduce(math.max);
    }

    test(
      'scores a centre-of-frame edge above an identical top-of-frame one',
      () async {
        // Subjects sit centre-frame; power lines, rooflines and foreground
        // clutter collect at the top and bottom. Weighting rows by how central
        // they are is what stops a seam treating a softly-lit face as no more
        // of an obstacle than the texture above it.
        const samples = 600;
        final profile = await ImageProcessor().computeEdgeEnergyProfile(
          twoBars(w: 800, h: 500),
          samples: samples,
        );

        final topBar = peakNear(profile, 0.25);
        final centreBar = peakNear(profile, 0.75);

        expect(centreBar, greaterThan(topBar));
        // The centre bar should be the profile's peak, i.e. the offset search
        // treats it as the thing most worth dodging.
        expect(centreBar, closeTo(profile.reduce(math.max), 1e-9));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    test(
      'still registers an edge that only touches the frame edge',
      () async {
        // Weighted down, not erased: a horizon slicing the very top of frame is
        // a lesser hazard than a torso through the middle, but it is not a free
        // place to cut.
        const samples = 600;
        final profile = await ImageProcessor().computeEdgeEnergyProfile(
          twoBars(w: 800, h: 500),
          samples: samples,
        );

        final topBar = peakNear(profile, 0.25);
        final flat = peakNear(profile, 0.5);

        expect(topBar, greaterThan(flat + 0.1));
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
