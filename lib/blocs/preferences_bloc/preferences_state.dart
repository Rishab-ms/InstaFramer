import 'package:equatable/equatable.dart';
import '../../models/user_preferences.dart';

abstract class PreferencesState extends Equatable {
  const PreferencesState();

  @override
  List<Object?> get props => [];
}

class PreferencesInitial extends PreferencesState {
  const PreferencesInitial();
}

class PreferencesLoading extends PreferencesState {
  const PreferencesLoading();
}

class PreferencesLoaded extends PreferencesState {
  final UserPreferences preferences;

  const PreferencesLoaded(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

class PreferencesError extends PreferencesState {
  final String message;

  const PreferencesError(this.message);

  @override
  List<Object?> get props => [message];
}

