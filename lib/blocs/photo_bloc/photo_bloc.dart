import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/export_service.dart';
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

  PhotoBloc({
    required ExportService exportService,
    required PreferencesService preferencesService,
  })  : _exportService = exportService,
        _preferencesService = preferencesService,
        super(const PhotoInitialState()) {
    on<LoadPhotosFromGalleryEvent>(_onLoadPhotosFromGallery);
    on<PhotosSelectedEvent>(_onPhotosSelected);
    on<UpdatePhotoSettingsEvent>(_onUpdatePhotoSettings);
    on<UpdateAspectRatioEvent>(_onUpdateAspectRatio);
    on<UpdateScaleEvent>(_onUpdateScale);
    on<UpdateBackgroundTypeEvent>(_onUpdateBackgroundType);
    on<UpdateBlurIntensityEvent>(_onUpdateBlurIntensity);
    on<UpdateCurrentIndexEvent>(_onUpdateCurrentIndex);
    on<ExportAllPhotosEvent>(_onExportAllPhotos);
    on<ClearPhotosEvent>(_onClearPhotos);
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
  /// Loads last used scale and blur intensity from preferences.
  Future<void> _onPhotosSelected(
    PhotosSelectedEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (event.photos.isEmpty) {
      emit(const PhotoErrorState('No photos selected'));
      return;
    }

    if (event.photos.length > 30) {
      emit(const PhotoErrorState('Maximum 30 photos allowed'));
      return;
    }

    // Load saved preferences to restore last used scale and blur intensity
    final prefs = await _preferencesService.loadPreferences();

    emit(PhotosLoadedState(
      photos: event.photos,
      settings: PhotoSettings(
        scale: prefs.lastUsedScale,
        blurIntensity: prefs.lastUsedBlurIntensity,
      ),
    ));
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
  /// 
  /// Processes photos one at a time to avoid memory issues.
  /// Emits progress updates via PhotosProcessingState.
  Future<void> _onExportAllPhotos(
    ExportAllPhotosEvent event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is! PhotosLoadedState) return;

    final currentState = state as PhotosLoadedState;
    try {
      // Process photos and emit progress updates
      await for (final progress in _exportService.exportPhotos(
        photos: currentState.photos,
        settings: currentState.settings,
      )) {
        emit(PhotosProcessingState(
          current: progress,
          total: currentState.photos.length,
        ));
      }

      // Export complete - emit success state
      emit(PhotosExportedState(currentState.photos.length));
      
      // Note: We don't automatically return to loaded state here.
      // The UI will handle navigation and clear photos when appropriate.
    } catch (e) {
      emit(PhotoErrorState('Export failed: $e'));
      // Return to loaded state so user can retry
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState);
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

