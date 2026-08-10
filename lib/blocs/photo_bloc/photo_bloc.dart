import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_handler/share_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../models/enums.dart';
import '../../models/panorama_spec.dart';
import '../../services/export_service.dart';
import '../../services/photo_permission_service.dart';
import '../../services/preferences_service.dart';
import 'photo_event.dart';
import 'photo_state.dart';
import '../../models/photo_settings.dart';

/// BLoC for managing photo selection and editing workflow.
///
/// Handles:
/// - Photo gallery selection
/// - Photo settings (aspect ratio, scale, background, blur intensity)
/// - Live preview state management
/// - Batch export with progress tracking
/// - Persistence of user's last used scale and blur settings
class PhotoBloc extends Bloc<PhotoEvent, PhotoState> {
  final ExportService _exportService;
  final PreferencesService _preferencesService;
  StreamSubscription? _shareSubscription;
  bool _shareListenerInitialized = false;

  PhotoBloc({
    required ExportService exportService,
    required PreferencesService preferencesService,
  }) : _exportService = exportService,
       _preferencesService = preferencesService,
       super(const PhotoInitialState()) {
    _initShareListener();
    on<LoadPhotosFromGalleryEvent>(_onLoadPhotosFromGallery);
    on<PhotosSelectedEvent>(_onPhotosSelected);
    on<ExternalMediaSharedEvent>(_onExternalMediaShared);
    on<UpdatePhotoSettingsEvent>(_onUpdatePhotoSettings);
    on<UpdateAspectRatioEvent>(_onUpdateAspectRatio);
    on<UpdateScaleEvent>(_onUpdateScale);
    on<UpdateBackgroundTypeEvent>(_onUpdateBackgroundType);
    on<UpdateBlurIntensityEvent>(_onUpdateBlurIntensity);
    on<UpdateCurrentIndexEvent>(_onUpdateCurrentIndex);
    on<ExportAllPhotosEvent>(_onExportAllPhotos);
    on<ClearPhotosEvent>(_onClearPhotos);
  }

  /// Initializes the inbound share listener (Android-only for now).
  ///
  /// Notes:
  /// - We subscribe to `sharedMediaStream` **before** reading initial media to
  ///   avoid missing a warm-share event during startup races.
  /// - This is idempotent to keep hot restarts / rebuilds safe.
  /// - Platform failures are swallowed so app startup can't be crashed by share
  ///   plumbing.
  void _initShareListener() async {
    if (_shareListenerInitialized) return;
    _shareListenerInitialized = true;

    final handler = ShareHandlerPlatform.instance;

    // Handle "Warm Start" (app already running / backgrounded)
    _shareSubscription = handler.sharedMediaStream.listen(_processMedia);

    // Handle "Cold Start" (app launched via share intent)
    try {
      final initialMedia = await handler.getInitialSharedMedia();
      if (initialMedia != null) {
        _processMedia(initialMedia);
      }
    } catch (_) {
      // If the platform handler throws, do not crash app startup.
    }
  }

  void _processMedia(SharedMedia media) {
    // Share callbacks may arrive after bloc disposal (e.g. app exit).
    if (isClosed) return;
    final paths = media.attachments
        ?.where((a) => a?.type == SharedAttachmentType.image)
        .map((a) => a!.path)
        .toList();

    if (paths != null && paths.isNotEmpty) {
      // BLoC rule of thumb:
      // - Use `emit(...)` only inside an `on<Event>((event, emit) { ... })` handler.
      // - If you're in a callback (like this platform share stream), use `add(...)`
      //   to enqueue an event and let the bloc handle it in one place.
      // Otherwise, calling `emit` from here can cause confusing state ordering
      // (it bypasses the bloc's event queue), and can even fail if it happens
      // while the bloc is already processing another event.
      add(ExternalMediaSharedEvent(paths));
    }
  }

  @override
  Future<void> close() {
    _shareSubscription?.cancel();
    return super.close();
  }

  /// Handle photo gallery picker launch.
  /// Transitions to loading state - actual picking happens in UI layer.
  Future<void> _onLoadPhotosFromGallery(
    LoadPhotosFromGalleryEvent event,
    Emitter<PhotoState> emit,
  ) async {
    emit(const PhotosLoadingState());
  }

  /// Handle photo selection from gallery.
  /// Validates photo count (1-30) and transitions to loaded state.
  /// If photos already exist, merges new selection with existing photos.
  /// Loads last used scale and blur intensity from preferences.
  Future<void> _onPhotosSelected(
    PhotosSelectedEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (event.photos.isEmpty) {
      emit(const PhotoErrorState('No photos selected'));
      return;
    }

    // Check if we already have photos loaded and merge them
    List<AssetEntity> finalPhotos;
    int currentIndex = 0;

    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      // Merge existing photos with newly selected photos
      final existingPhotos = List<AssetEntity>.from(currentState.photos);
      final newPhotos = event.photos
          .where(
            (newPhoto) =>
                !existingPhotos.any((existing) => existing.id == newPhoto.id),
          )
          .toList();

      finalPhotos = existingPhotos + newPhotos;
      currentIndex = currentState.currentIndex; // Keep current index
    } else {
      // No existing photos, use the selected ones
      finalPhotos = event.photos;
    }

    if (finalPhotos.length > 30) {
      emit(const PhotoErrorState('Maximum 30 photos allowed'));
      return;
    }

    // Load saved preferences to restore last used scale and blur intensity
    final prefs = await _preferencesService.loadPreferences();

    emit(
      PhotosLoadedState(
        photos: finalPhotos,
        currentIndex: currentIndex,
        settings: PhotoSettings(
          scale: prefs.lastUsedScale,
          blurIntensity: prefs.lastUsedBlurIntensity,
        ),
      ),
    );
  }

  /// Handles shared file paths coming in via the platform share sheet.
  ///
  /// The editor/export pipeline is currently built around `AssetEntity`, so we
  /// bridge the incoming paths into `AssetEntity` values using
  /// `PhotoManager.editor.saveImageWithPath`.
  ///
  /// Trade-off: `saveImageWithPath` imports/copies the file into the user’s
  /// photo library so it can be represented as an `AssetEntity`. Avoiding
  /// gallery duplication would require a broader refactor to support a `File` /
  /// bytes-backed model end-to-end.
  Future<void> _onExternalMediaShared(
    ExternalMediaSharedEvent event,
    Emitter<PhotoState> emit,
  ) async {
    emit(const PhotosLoadingState());

    final hasPermission =
        await PhotoPermissionService.requestPhotosPermission();
    if (!hasPermission) {
      emit(const PhotoErrorState('Photo permission denied'));
      return;
    }

    final uniquePaths = event.filePaths
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList();

    final resolvedPaths = <String>[];
    for (final p in uniquePaths) {
      final resolvedPath = p.startsWith('file://')
          ? Uri.parse(p).toFilePath()
          : p;
      if (await File(resolvedPath).exists()) {
        resolvedPaths.add(resolvedPath);
      }
    }

    if (resolvedPaths.isEmpty) {
      emit(const PhotoErrorState('No valid shared images found'));
      return;
    }

    final assets = <AssetEntity>[];
    for (final path in resolvedPaths.take(30)) {
      try {
        final title = path.split(Platform.pathSeparator).last;
        final entity = await PhotoManager.editor.saveImageWithPath(
          path,
          title: title,
        );
        assets.add(entity);
      } catch (_) {
        // Skip unreadable paths.
      }
    }

    if (assets.isEmpty) {
      emit(const PhotoErrorState('Failed to import shared images'));
      return;
    }

    final currentState = state is PhotosLoadedState
        ? state as PhotosLoadedState
        : null;

    // A fresh single share (no editor session already in flight) that's
    // wide enough for a panorama gets a mode choice instead of landing
    // straight in the framer — see SharedPhotoModeSelectionState and
    // CreateModeDialog. A second share arriving while an editor is open, or
    // a multi-photo share, always goes straight to the merge below.
    final freshSingle = assets.length == 1 && currentState == null;
    if (freshSingle) {
      final asset = assets.first;
      final PanoramaEligibility eligibility = PanoramaSpec.evaluate(
        sourceWidth: asset.orientatedWidth,
        sourceHeight: asset.orientatedHeight,
        tileRatio: PanoramaTileRatio.portrait.ratio,
      );
      if (eligibility.isEligible) {
        emit(SharedPhotoModeSelectionState(asset));
        return;
      }
    }

    final existingPhotos = currentState?.photos ?? const <AssetEntity>[];
    final newPhotos = assets
        .where(
          (newPhoto) =>
              !existingPhotos.any((existing) => existing.id == newPhoto.id),
        )
        .toList();

    final merged = (existingPhotos + newPhotos);
    final capped = merged.length > 30 ? merged.sublist(0, 30) : merged;

    final prefs = await _preferencesService.loadPreferences();
    emit(
      PhotosLoadedState(
        photos: capped,
        currentIndex: currentState?.currentIndex ?? 0,
        settings:
            currentState?.settings ??
            PhotoSettings(
              scale: prefs.lastUsedScale,
              blurIntensity: prefs.lastUsedBlurIntensity,
            ),
      ),
    );
  }

  /// Update all photo settings at once.
  Future<void> _onUpdatePhotoSettings(
    UpdatePhotoSettingsEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      emit(currentState.copyWith(settings: event.settings));
    }
  }

  /// Update only the aspect ratio setting.
  Future<void> _onUpdateAspectRatio(
    UpdateAspectRatioEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      final updatedSettings = currentState.settings.copyWith(
        aspectRatio: event.aspectRatio,
      );
      emit(currentState.copyWith(settings: updatedSettings));
    }
  }

  /// Update only the scale setting and persist to preferences.
  Future<void> _onUpdateScale(
    UpdateScaleEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      final updatedSettings = currentState.settings.copyWith(
        scale: event.scale,
      );
      emit(currentState.copyWith(settings: updatedSettings));

      // Save to preferences for next session
      final prefs = await _preferencesService.loadPreferences();
      await _preferencesService.savePreferences(
        prefs.copyWith(lastUsedScale: event.scale),
      );
    }
  }

  /// Update only the background type setting.
  Future<void> _onUpdateBackgroundType(
    UpdateBackgroundTypeEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      final updatedSettings = currentState.settings.copyWith(
        backgroundType: event.backgroundType,
      );
      emit(currentState.copyWith(settings: updatedSettings));
    }
  }

  /// Update only the blur intensity setting and persist to preferences.
  Future<void> _onUpdateBlurIntensity(
    UpdateBlurIntensityEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      final updatedSettings = currentState.settings.copyWith(
        blurIntensity: event.intensity,
      );
      emit(currentState.copyWith(settings: updatedSettings));

      // Save to preferences for next session
      final prefs = await _preferencesService.loadPreferences();
      await _preferencesService.savePreferences(
        prefs.copyWith(lastUsedBlurIntensity: event.intensity),
      );
    }
  }

  /// Update the current photo index in carousel.
  Future<void> _onUpdateCurrentIndex(
    UpdateCurrentIndexEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoadedState) {
      final currentState = state as PhotosLoadedState;
      emit(currentState.copyWith(currentIndex: event.index));
    }
  }

  /// Export all photos with current settings.
  /// Emits PhotosProcessingState with progress updates.
  /// Emits PhotosExportedState when export is complete.
  /// Emits PhotoErrorState if export fails.
  Future<void> _onExportAllPhotos(
    ExportAllPhotosEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is! PhotosLoadedState) return;
    WakelockPlus.enable(); // Prevent device from sleeping

    final currentState = state as PhotosLoadedState;
    try {
      // Load preferences to get last used scale and blur intensity
      final preferences = await _preferencesService.loadPreferences();

      // 1. Emit 0% Progress IMMEDIATELY.
      // This forces the UI to switch to the "Processing View" instantly.
      emit(
        PhotosProcessingState(
          current: 0,
          total: currentState.photos.length,
          backgroundType: currentState.settings.backgroundType,
          photos: currentState.photos,
        ),
      );

      // 2. Give the UI a tiny moment to render the new screen
      // before we start blocking the thread with directory creation/logic.
      await Future.delayed(const Duration(milliseconds: 50));

      // 3. Now start the heavy stream
      await for (final progress in _exportService.exportPhotos(
        photos: currentState.photos,
        settings: currentState.settings,
        preserveMetadata: preferences.preserveMetadata,
      )) {
        emit(
          PhotosProcessingState(
            current: progress,
            total: currentState.photos.length,
            backgroundType: currentState.settings.backgroundType,
            photos: currentState.photos,
          ),
        );
      }

      emit(PhotosExportedState(currentState.photos.length));
    } catch (e) {
      emit(PhotoErrorState('Export failed: $e'));
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState);
    } finally {
      WakelockPlus.disable(); // Allow device to sleep again
    }
  }

  /// Clear all photos and reset to initial state.
  Future<void> _onClearPhotos(
    ClearPhotosEvent event,
    Emitter<PhotoState> emit,
  ) async {
    emit(const PhotoInitialState());
  }
}
