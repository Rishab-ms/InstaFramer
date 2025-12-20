import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/export_service.dart';
import 'photo_event.dart';
import 'photo_state.dart';
import '../../models/photo_settings.dart';

class PhotoBloc extends Bloc<PhotoEvent, PhotoState> {
  final ExportService _exportService;

  PhotoBloc({required ExportService exportService})
      : _exportService = exportService,
        super(const PhotoInitial()) {
    on<LoadPhotosFromGallery>(_onLoadPhotosFromGallery);
    on<PhotosSelected>(_onPhotosSelected);
    on<UpdatePhotoSettings>(_onUpdatePhotoSettings);
    on<UpdateAspectRatio>(_onUpdateAspectRatio);
    on<UpdateScale>(_onUpdateScale);
    on<UpdateBackgroundType>(_onUpdateBackgroundType);
    on<UpdateCurrentIndex>(_onUpdateCurrentIndex);
    on<ExportAllPhotos>(_onExportAllPhotos);
    on<ClearPhotos>(_onClearPhotos);
  }

  Future<void> _onLoadPhotosFromGallery(
    LoadPhotosFromGallery event,
    Emitter<PhotoState> emit,
  ) async {
    emit(const PhotosLoading());
  }

  Future<void> _onPhotosSelected(
    PhotosSelected event,
    Emitter<PhotoState> emit,
  ) async {
    if (event.photos.isEmpty) {
      emit(const PhotoError('No photos selected'));
      return;
    }

    if (event.photos.length > 30) {
      emit(const PhotoError('Maximum 30 photos allowed'));
      return;
    }

    emit(PhotosLoaded(
      photos: event.photos,
      settings: const PhotoSettings(),
    ));
  }

  Future<void> _onUpdatePhotoSettings(
    UpdatePhotoSettings event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoaded) {
      final currentState = state as PhotosLoaded;
      emit(currentState.copyWith(settings: event.settings));
    }
  }

  Future<void> _onUpdateAspectRatio(
    UpdateAspectRatio event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoaded) {
      final currentState = state as PhotosLoaded;
      final updatedSettings = currentState.settings.copyWith(
        aspectRatio: event.aspectRatio,
      );
      emit(currentState.copyWith(settings: updatedSettings));
    }
  }

  Future<void> _onUpdateScale(
    UpdateScale event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoaded) {
      final currentState = state as PhotosLoaded;
      final updatedSettings = currentState.settings.copyWith(
        scale: event.scale,
      );
      emit(currentState.copyWith(settings: updatedSettings));
    }
  }

  Future<void> _onUpdateBackgroundType(
    UpdateBackgroundType event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoaded) {
      final currentState = state as PhotosLoaded;
      final updatedSettings = currentState.settings.copyWith(
        backgroundType: event.backgroundType,
      );
      emit(currentState.copyWith(settings: updatedSettings));
    }
  }

  Future<void> _onUpdateCurrentIndex(
    UpdateCurrentIndex event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is PhotosLoaded) {
      final currentState = state as PhotosLoaded;
      emit(currentState.copyWith(currentIndex: event.index));
    }
  }

  Future<void> _onExportAllPhotos(
    ExportAllPhotos event,
    Emitter<PhotoState> emit,
  ) async {
    if (state is! PhotosLoaded) return;

    final currentState = state as PhotosLoaded;
    try {
      await for (final progress in _exportService.exportPhotos(
        photos: currentState.photos,
        settings: currentState.settings,
      )) {
        emit(PhotosProcessing(
          current: progress,
          total: currentState.photos.length,
        ));
      }

      emit(PhotosExported(currentState.photos.length));
      
      // Return to loaded state after a brief moment
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState);
    } catch (e) {
      emit(PhotoError('Export failed: $e'));
      // Return to loaded state
      await Future.delayed(const Duration(seconds: 2));
      emit(currentState);
    }
  }

  Future<void> _onClearPhotos(
    ClearPhotos event,
    Emitter<PhotoState> emit,
  ) async {
    emit(const PhotoInitial());
  }
}

