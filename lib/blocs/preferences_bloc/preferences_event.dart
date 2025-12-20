import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../models/image_size.dart';

abstract class PreferencesEvent extends Equatable {
  const PreferencesEvent();

  @override
  List<Object?> get props => [];
}

class LoadPreferences extends PreferencesEvent {
  const LoadPreferences();
}

class UpdateThemeMode extends PreferencesEvent {
  final ThemeMode themeMode;

  const UpdateThemeMode(this.themeMode);

  @override
  List<Object?> get props => [themeMode];
}

class UpdateImageQuality extends PreferencesEvent {
  final int quality;

  const UpdateImageQuality(this.quality);

  @override
  List<Object?> get props => [quality];
}

class UpdateImageSizePreset extends PreferencesEvent {
  final ImageSizePreset preset;

  const UpdateImageSizePreset(this.preset);

  @override
  List<Object?> get props => [preset];
}

class UpdateCustomImageSize extends PreferencesEvent {
  final ImageSize size;

  const UpdateCustomImageSize(this.size);

  @override
  List<Object?> get props => [size];
}

