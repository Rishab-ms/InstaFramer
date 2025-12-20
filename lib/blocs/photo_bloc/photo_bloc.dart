import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/export_service.dart';
import 'photo_event.dart';
import 'photo_state.dart';
import '../../models/photo_settings.dart';

/// BLoC for managing photo selection and editing workflow.
/// 
/// Handles:
/// - Photo gallery selection
/// - Photo settings (aspect ratio, scale, background)
/// - Live preview state management
/// - Batch export with progress tracking
class PhotoBloc extends Bloc<PhotoEvent, PhotoState> {
  final ExportService _exportService;

  PhotoBloc({required ExportService exportService})
      : _exportService = exportService,
        super(const PhotoInitialState()) {
    on<LoadPhotosFromGalleryEvent>(_onLoadPhotosFromGallery);
    on<PhotosSelectedEvent>(_onPhotosSelected);
    on<UpdatePhotoSettingsEvent>(_onUpdatePhotoSettings);
    on<UpdateAspectRatioEvent>(_onUpdateAspectRatio);
    on<UpdateScaleEvent>(_onUpdateScale);
    on<UpdateBackgroundTypeEvent>(_onUpdateBackgroundType);
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

    emit(PhotosLoadedState(
      photos: event.photos,
      settings: const PhotoSettings(), // Default settings
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

  /// Update only the scale setting.
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

      // Export complete
      emit(PhotosExportedState(currentState.photos.length));
      
      // Return to loaded state after brief display
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState);
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

