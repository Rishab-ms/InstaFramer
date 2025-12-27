import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/preferences_bloc/preferences_bloc.dart';
import '../../blocs/preferences_bloc/preferences_event.dart';
import 'radio_list_tile_option.dart';
import 'settings_card.dart';

/// Theme mode selector widget with System/Light/Dark options.
/// 
/// Displays three radio button options for theme selection:
/// - System Default (follows device settings)
/// - Light Theme
/// - Dark Theme
/// 
/// Updates PreferencesBloc when selection changes.
class ThemeModeSelector extends StatelessWidget {
  /// The currently selected theme mode
  final ThemeMode currentMode;

  const ThemeModeSelector({
    super.key,
    required this.currentMode,
  });

  void _onThemeModeChanged(BuildContext context, ThemeMode mode) {
    context.read<PreferencesBloc>().add(UpdateThemeModeEvent(mode));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        children: [
          RadioListTileOption<ThemeMode>(
            value: ThemeMode.system,
            groupValue: currentMode,
            onChanged: (mode) => _onThemeModeChanged(context, mode),
            icon: Icons.brightness_auto,
            title: 'System Default',
            subtitle: 'Follow device settings',
          ),
          const Divider(height: 1),
          RadioListTileOption<ThemeMode>(
            value: ThemeMode.light,
            groupValue: currentMode,
            onChanged: (mode) => _onThemeModeChanged(context, mode),
            icon: Icons.light_mode,
            title: 'Light Theme',
            subtitle: 'Bright and vibrant',
          ),
          const Divider(height: 1),
          RadioListTileOption<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: currentMode,
            onChanged: (mode) => _onThemeModeChanged(context, mode),
            icon: Icons.dark_mode,
            title: 'Dark Theme',
            subtitle: 'Easy on the eyes',
          ),
        ],
      ),
    );
  }
}




