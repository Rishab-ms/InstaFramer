import 'image_size.dart';

/// Background painted behind the photo when it doesn't fill the canvas.
enum BackgroundType {
  white('White'),
  black('Black'),
  extendedBlur('Blur');

  const BackgroundType(this.displayName);

  final String displayName;
}

/// Export dimension presets offered in preferences.
///
/// ⚠️ Persisted by `index` (`UserPreferences.toJson`), so the declaration order
/// is load-bearing — appending is safe, reordering or removing silently
/// remaps every existing user's saved preset.
enum ImageSizePreset {
  instagramPortrait(
    'Instagram Portrait - 1080×1350',
    ImageSize(width: 1080, height: 1350),
  ),
  instagramSquare(
    'Instagram Square - 1080×1080',
    ImageSize(width: 1080, height: 1080),
  ),
  instagramLandscape(
    'Instagram Landscape - 1080×566',
    ImageSize(width: 1080, height: 566),
  ),
  highQualityPortrait(
    'High Quality Portrait - 1440×1800',
    ImageSize(width: 1440, height: 1800),
  ),
  highQualitySquare(
    'High Quality Square - 1440×1440',
    ImageSize(width: 1440, height: 1440),
  ),
  custom(
    'Custom Size',
    // Only a starting point — the real value comes from
    // UserPreferences.customImageSize.
    ImageSize(width: 1080, height: 1350),
  );

  const ImageSizePreset(this.displayName, this.size);

  final String displayName;
  final ImageSize size;
}

/// How the source photo is placed into the panorama canvas.
enum PanoramaFitMode {
  /// Contain-fit, leftover padded with the background. Nothing is cropped —
  /// scale and background controls apply.
  fit('Fit'),

  /// Cover-fit + centre crop. No bars, so background and scale are meaningless.
  fill('Fill');

  const PanoramaFitMode(this.displayName);

  final String displayName;
}

/// Phase of a panorama export.
///
/// Two-phase because the single `processPanorama` isolate call fully renders
/// the canvas before any tile exists to save — a naive single-percentage
/// stream would sit at 0% then jump. `rendering` is indeterminate; `saving`
/// is determinate, one tick per tile committed to the gallery.
enum PanoramaExportPhase { rendering, saving }
