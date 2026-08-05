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
    test('slices into exact 4:5 tiles in every fit mode and background', () async {
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
              seamOffset: 0.4,
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
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Fit bounds the seam nudge to the slack inside the bars', () async {
      final source = gradientSource(4000, 1250);

      Future<List<Uint8List>> render(double scale, double seamOffset) =>
          processor.processPanorama(
            source,
            PanoramaSettings(
              tileCount: 4,
              scale: scale,
              seamOffset: seamOffset,
            ),
          );

      // At scale 1.0 the photo spans the full canvas width, so there is no
      // slack. Fit promises nothing is cropped, so the nudge must be a no-op
      // rather than pushing content off the edge.
      expect(await render(1.0, 0.4), equals(await render(1.0, 0.0)));

      // At scale 0.8 there are bars to slide within, so the nudge must apply.
      expect(await render(0.8, 0.4), isNot(equals(await render(0.8, 0.0))));
    }, timeout: const Timeout(Duration(minutes: 5)));

    test('Fill nudges only when the source is wider than the canvas', () async {
      // Source aspect 3.2 == the 4-tile canvas aspect, so the cover crop keeps
      // the full source width and there is no horizontal slack to nudge into.
      final exact = gradientSource(4000, 1250);
      final tight0 = await processor.processPanorama(exact,
          const PanoramaSettings(tileCount: 4, fitMode: PanoramaFitMode.fill));
      final tight4 = await processor.processPanorama(
          exact,
          const PanoramaSettings(
              tileCount: 4, fitMode: PanoramaFitMode.fill, seamOffset: 0.4));
      expect(tight4, equals(tight0));

      // Source aspect 4.8 into the same 3.2 canvas: the sides get cropped, so
      // there is slack and the nudge shifts the crop window.
      final wide = gradientSource(6000, 1250);
      final wide0 = await processor.processPanorama(wide,
          const PanoramaSettings(tileCount: 4, fitMode: PanoramaFitMode.fill));
      final wide4 = await processor.processPanorama(
          wide,
          const PanoramaSettings(
              tileCount: 4, fitMode: PanoramaFitMode.fill, seamOffset: 0.4));
      expect(wide4, isNot(equals(wide0)));

      // The nudge must not shrink the last tile by running the crop window off
      // the source edge — that is what the clamp in _coverCropResize prevents.
      expect(img.decodeImage(wide4.last)!.width, 1080);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}
