import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/preferences_service.dart';
import 'preferences_event.dart';
import 'preferences_state.dart';

/// BLoC for managing user preferences and app settings.
/// 
/// Handles:
/// - Loading and saving preferences from persistent storage
/// - Theme mode (system/light/dark)
/// - Image quality settings (1-100)
/// - Image size presets and custom dimensions
class PreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  final PreferencesService _preferencesService;

  PreferencesBloc({required PreferencesService preferencesService})
      : _preferencesService = preferencesService,
        super(const PreferencesInitialState()) {
    on<LoadPreferencesEvent>(_onLoadPreferences);
    on<UpdateThemeModeEvent>(_onUpdateThemeMode);
    on<UpdateImageQualityEvent>(_onUpdateImageQuality);
    on<UpdateImageSizePresetEvent>(_onUpdateImageSizePreset);
    on<UpdateCustomImageSizeEvent>(_onUpdateCustomImageSize);
  }

  /// Load user preferences from persistent storage on app start.
  /// Falls back to default preferences if none exist.
  Future<void> _onLoadPreferences(
    LoadPreferencesEvent event,
    Emitter<PreferencesState> emit,
  ) async {
    try {
      emit(const PreferencesLoadingState());
      final preferences = await _preferencesService.loadPreferences();
      emit(PreferencesLoadedState(preferences));
    } catch (e) {
      emit(PreferencesErrorState('Failed to load preferences: $e'));
    }
  }

  /// Update theme mode and persist to storage.
  Future<void> _onUpdateThemeMode(
    UpdateThemeModeEvent event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoadedState) {
      final currentState = state as PreferencesLoadedState;
      final updatedPreferences = currentState.preferences.copyWith(
        themeMode: event.themeMode,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoadedState(updatedPreferences));
    }
  }

  /// Update image quality setting and persist to storage.
  Future<void> _onUpdateImageQuality(
    UpdateImageQualityEvent event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoadedState) {
      final currentState = state as PreferencesLoadedState;
      final updatedPreferences = currentState.preferences.copyWith(
        imageQuality: event.quality,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoadedState(updatedPreferences));
    }
  }

  /// Update image size preset and persist to storage.
  Future<void> _onUpdateImageSizePreset(
    UpdateImageSizePresetEvent event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoadedState) {
      final currentState = state as PreferencesLoadedState;
      final updatedPreferences = currentState.preferences.copyWith(
        imageSizePreset: event.preset,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoadedState(updatedPreferences));
    }
  }

  /// Update custom image size and persist to storage.
  Future<void> _onUpdateCustomImageSize(
    UpdateCustomImageSizeEvent event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoadedState) {
      final currentState = state as PreferencesLoadedState;
      final updatedPreferences = currentState.preferences.copyWith(
        customImageSize: event.size,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoadedState(updatedPreferences));
    }
  }
}

