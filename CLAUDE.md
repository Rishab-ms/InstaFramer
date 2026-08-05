# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

InstaFramer (package name `insta_upload_helper`) is a Flutter app that batch-frames photos for Instagram: consistent aspect ratio, scale, and background (white/black/blur) applied across up to 30 photos at once, then exported to the device gallery. Android is the primary supported platform; iOS support is planned but not yet implemented.

## Commands

```bash
flutter pub get                    # install dependencies
flutter run                        # run on connected device/emulator
flutter analyze                    # lint (uses flutter_lints via analysis_options.yaml)
flutter test                       # run tests (no test/ directory exists yet)
flutter build apk --release        # release APK
flutter build appbundle --release  # Play Store bundle
```

There is no single-test-file convention yet since the project has no `test/` directory — when adding tests, standard `flutter test test/path/to/file_test.dart` applies.

### Releases

`./scripts/create_release.sh <version>` builds a release APK, renames it, tags it, and pushes the tag. Pushing a `vX.Y.Z` tag triggers `.github/workflows/release.yml`, which builds the APK on GitHub Actions and attaches it to a GitHub Release. Don't push version tags without the user's explicit go-ahead — it triggers a public release.

## Engineering Principles

- Do not preserve backward compatibility for internal code. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirement. Avoid speculative abstractions, config knobs, or indirection for features that don't exist yet.
- Grow the app in layers. Keep it in a state that builds and runs end to end; add each new capability on top of a working product rather than leaving it half-wired.
- Keep blocs, services, models, and widgets in their own layer (see Architecture below) — a screen should not talk to `image` or `photo_manager` directly, it goes through a bloc and a service.
- Prefer the packages already in `pubspec.yaml` over hand-rolled equivalents or new dependencies. Check what `image`, `photo_manager`, `flutter_bloc`, etc. already provide before writing custom logic — but don't add a new package for something a few lines of Dart already covers.
- Make architectural calls (bloc structure, isolate boundaries, model shapes) for the long term. Don't land a stopgap that's known to need replacing once "the real version" is built.

## Architecture

BLoC pattern (`flutter_bloc`) with two top-level blocs provided in `main.dart` via `MultiBlocProvider`:

- **`PreferencesBloc`** (`lib/blocs/preferences_bloc/`) — loads `UserPreferences` from `SharedPreferences` on startup (`LoadPreferencesEvent`), drives `MaterialApp.themeMode`, and persists settings (theme, JPEG quality, export image size, last-used scale/blur intensity, preserve-metadata toggle) immediately on change.
- **`PhotoBloc`** (`lib/blocs/photo_bloc/`) — owns the photo selection → edit → export workflow. Key states: `PhotoInitialState` → `PhotosLoadingState` → `PhotosLoadedState(photos, settings, currentIndex)` → `PhotosProcessingState(progress)` → `PhotosExportedState`. Naming convention throughout the codebase: all events end in `Event`, all states end in `State`.

Both blocs are constructed with injected services (`ExportService`, `PreferencesService`) rather than instantiating them internally — follow this pattern for new services.

### Photo import paths

`PhotoBloc` populates `PhotosLoadedState.photos` (a `List<AssetEntity>`) two ways:

1. **In-app gallery pick** — `PhotosSelectedEvent`, sourced from `wechat_assets_picker` in `photo_picker_screen.dart`.
2. **External share intent** (Android only) — `share_handler` package. `PhotoBloc._initShareListener()` subscribes to `ShareHandlerPlatform.instance.sharedMediaStream` *before* checking `getInitialSharedMedia()`, to avoid a startup race on cold-start shares. Incoming file paths are bridged into `AssetEntity` via `PhotoManager.editor.saveImageWithPath`, which copies the file into the user's photo library (the editor/export pipeline is built entirely around `AssetEntity`, not raw files/bytes). Both paths converge on the same merge logic that caps the library at 30 photos.

Bloc rule the codebase follows strictly: only call `emit()` inside an `on<Event>` handler. Callbacks (e.g. the share stream listener) must `add()` an event instead of emitting directly, or state ordering breaks.

### Image processing pipeline

- **`ImageProcessor`** (`lib/services/image_processor.dart`) does all decode/resize/blur/encode work using the `image` package, run off the main thread via Flutter's `compute()` (isolates) — never inline on the UI thread. The isolate entry point (`_processImageInIsolate`) and its params class must stay static/top-level and hold only serializable data (`Uint8List`, primitives, `PhotoSettings`).
- Aspect ratios are data-driven, not enums — `AspectRatio` (`lib/models/aspect_ratio.dart`) is a class with `id`, `ratio`, `displayName`, `iconName`, etc., and `AspectRatios.all` is the source list the UI renders buttons from dynamically. To add a new ratio, add an entry to that list — no UI or processing code changes needed since sizing formulas are `height = width / ratio` generically.
- Blur backgrounds are generated cheaply: downscale the source to ~300px, blur, then upscale — never blur at full resolution.
- Preview processing (carousel live preview) and export processing intentionally use different targets: previews use small thumbnails (600px, quality 75) for speed; export uses full resolution and the user's configured JPEG quality (`imageQuality`, clamped 70–95).

### Export pipeline

`ExportService.exportPhotos()` (`lib/services/export_service.dart`) is a `Stream<int>` that yields progress (count completed) as it goes, consumed by `PhotoBloc._onExportAllPhotos`. It processes in fixed-size concurrent batches (currently hardcoded to 3) rather than one-at-a-time or fully parallel, to balance speed against memory/OOM risk on-device. Each photo: read `AssetEntity.originBytes` once → process → optionally re-inject the original EXIF APP1 segment (`_preserveMetadata`, manual JPEG marker parsing — this is deliberately not using the `exif` package for the write path) → write to a temp dir → `Gal.putImage()` → delete the temp file. The temp export directory is cleaned up in a `finally` block regardless of success/failure. `WakelockPlus` is enabled for the duration of export so the screen doesn't sleep mid-batch.

### Models

`lib/models/` holds plain `Equatable` data classes (`PhotoSettings`, `UserPreferences`, `AspectRatio`, `BackgroundType`, `ImageSize`) — no business logic lives here. `PhotoSettings.copyWith` is the standard way blocs derive updated settings.

## Conventions carried over from the project's history (see `plans/implementation_plan.md`)

- BLoC events/states are suffixed `Event`/`State` respectively — keep this even though it's slightly redundant, it's an intentional readability choice for BLoC newcomers.
- Don't reintroduce automatic state-cycling in `PhotoBloc` (e.g. auto-transitioning `PhotosExportedState` back to `PhotosLoadedState`). This previously caused duplicate snackbar/navigation triggers; the fix was to emit a terminal state and let the UI explicitly dispatch `ClearPhotosEvent` before navigating away.
- When touching `BlocConsumer`/`BlocListener` usage in the UI, use `listenWhen` to gate one-shot side effects (snackbars, navigation) on an explicit previous→current state transition, not just "state changed."
- Theming is Material 3 via `flex_color_scheme` (`lib/theme/app_theme.dart`), with light/dark variants and a warm amber/orange palette. Theme mode must be read from `PreferencesBloc` before `MaterialApp` builds to avoid a flash of the wrong theme.
