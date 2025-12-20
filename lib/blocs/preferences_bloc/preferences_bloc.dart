import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/preferences_service.dart';
import 'preferences_event.dart';
import 'preferences_state.dart';

class PreferencesBloc extends Bloc<PreferencesEvent, PreferencesState> {
  final PreferencesService _preferencesService;

  PreferencesBloc({required PreferencesService preferencesService})
      : _preferencesService = preferencesService,
        super(const PreferencesInitial()) {
    on<LoadPreferences>(_onLoadPreferences);
    on<UpdateThemeMode>(_onUpdateThemeMode);
    on<UpdateImageQuality>(_onUpdateImageQuality);
    on<UpdateImageSizePreset>(_onUpdateImageSizePreset);
    on<UpdateCustomImageSize>(_onUpdateCustomImageSize);
  }

  Future<void> _onLoadPreferences(
    LoadPreferences event,
    Emitter<PreferencesState> emit,
  ) async {
    try {
      emit(const PreferencesLoading());
      final preferences = await _preferencesService.loadPreferences();
      emit(PreferencesLoaded(preferences));
    } catch (e) {
      emit(PreferencesError('Failed to load preferences: $e'));
    }
  }

  Future<void> _onUpdateThemeMode(
    UpdateThemeMode event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoaded) {
      final currentState = state as PreferencesLoaded;
      final updatedPreferences = currentState.preferences.copyWith(
        themeMode: event.themeMode,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoaded(updatedPreferences));
    }
  }

  Future<void> _onUpdateImageQuality(
    UpdateImageQuality event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoaded) {
      final currentState = state as PreferencesLoaded;
      final updatedPreferences = currentState.preferences.copyWith(
        imageQuality: event.quality,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoaded(updatedPreferences));
    }
  }

  Future<void> _onUpdateImageSizePreset(
    UpdateImageSizePreset event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoaded) {
      final currentState = state as PreferencesLoaded;
      final updatedPreferences = currentState.preferences.copyWith(
        imageSizePreset: event.preset,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoaded(updatedPreferences));
    }
  }

  Future<void> _onUpdateCustomImageSize(
    UpdateCustomImageSize event,
    Emitter<PreferencesState> emit,
  ) async {
    if (state is PreferencesLoaded) {
      final currentState = state as PreferencesLoaded;
      final updatedPreferences = currentState.preferences.copyWith(
        customImageSize: event.size,
      );
      await _preferencesService.savePreferences(updatedPreferences);
      emit(PreferencesLoaded(updatedPreferences));
    }
  }
}

