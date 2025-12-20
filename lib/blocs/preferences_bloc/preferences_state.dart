import 'package:equatable/equatable.dart';
import '../../models/user_preferences.dart';

/// Base class for all preferences-related states.
/// 
/// All PreferencesBloc states extend this class and follow the naming
/// convention of ending with "State" for clarity.
abstract class PreferencesState extends Equatable {
  const PreferencesState();

  @override
  List<Object?> get props => [];
}

/// Initial state before preferences are loaded.
/// 
/// This is the default state when PreferencesBloc is created.
class PreferencesInitialState extends PreferencesState {
  const PreferencesInitialState();
}

/// Loading state while preferences are being loaded from storage.
/// 
/// Transitions to this state when [LoadPreferencesEvent] is dispatched.
class PreferencesLoadingState extends PreferencesState {
  const PreferencesLoadingState();
}

/// Loaded state containing user preferences.
/// 
/// This is the main state containing all user settings:
/// - Theme mode (system/light/dark)
/// - Image quality (1-100)
/// - Image size preset and custom size
class PreferencesLoadedState extends PreferencesState {
  final UserPreferences preferences;

  const PreferencesLoadedState(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Error state when preferences fail to load or save.
/// 
/// Contains error [message] to display to user.
/// Falls back to default preferences on load error.
class PreferencesErrorState extends PreferencesState {
  final String message;

  const PreferencesErrorState(this.message);

  @override
  List<Object?> get props => [message];
}

