import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../models/image_size.dart';

/// Base class for all preferences-related events.
/// 
/// All PreferencesBloc events extend this class and follow the naming
/// convention of ending with "Event" for clarity.
abstract class PreferencesEvent extends Equatable {
  const PreferencesEvent();

  @override
  List<Object?> get props => [];
}

/// Event to load user preferences from persistent storage.
/// 
/// Dispatched on app start to restore user settings.
/// If no saved preferences exist, defaults are used.
class LoadPreferencesEvent extends PreferencesEvent {
  const LoadPreferencesEvent();
}

/// Event to update the app theme mode.
/// 
/// Options: [ThemeMode.system], [ThemeMode.light], or [ThemeMode.dark].
/// Change is persisted immediately and updates the UI.
class UpdateThemeModeEvent extends PreferencesEvent {
  final ThemeMode themeMode;

  const UpdateThemeModeEvent(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

/// Event to update the JPEG export quality.
/// 
/// Quality ranges from 1-100, where 100 is maximum quality.
/// Default is 85 for optimal size/quality balance.
class UpdateImageQualityEvent extends PreferencesEvent {
  final int quality;

  const UpdateImageQualityEvent(this.quality);

  @override
  List<Object?> get props => [quality];
}

/// Event to update the image size preset.
/// 
/// Presets include Instagram portrait/square/landscape and high quality variants.
/// See [ImageSizePreset] enum for all options.
class UpdateImageSizePresetEvent extends PreferencesEvent {
  final ImageSizePreset preset;

  const UpdateImageSizePresetEvent(this.preset);

  @override
  List<Object?> get props => [preset];
}

/// Event to set a custom image size.
/// 
/// Used when user selects "Custom" preset and provides specific dimensions.
class UpdateCustomImageSizeEvent extends PreferencesEvent {
  final ImageSize size;

  const UpdateCustomImageSizeEvent(this.size);

  @override
  List<Object?> get props => [size];
}

