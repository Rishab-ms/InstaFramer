import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/photo_bloc/photo_bloc.dart';
import 'blocs/preferences_bloc/preferences_bloc.dart';
import 'blocs/preferences_bloc/preferences_event.dart';
import 'blocs/preferences_bloc/preferences_state.dart';
import 'screens/home_screen.dart';
import 'services/export_service.dart';
import 'services/preferences_service.dart';
import 'theme/app_theme.dart';

/// Entry point of the InstaFramer application.
/// 
/// This app helps users frame photos perfectly for Instagram with:
/// - Customizable aspect ratios (4:5 portrait, 1:1 square)
/// - Adjustable scaling and positioning
/// - Beautiful backgrounds (white, black, or extended blur)
/// - Batch export functionality
void main() async {
  // Ensure Flutter bindings are initialized before accessing platform services
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const InstaFramerApp());
}

/// Root widget of the InstaFramer application.
/// 
/// Sets up the BLoC architecture with:
/// - [PreferencesBloc]: Manages user settings (theme, quality, size)
/// - [PhotoBloc]: Manages photo selection and editing workflow
class InstaFramerApp extends StatelessWidget {
  const InstaFramerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // Preferences BLoC - loads user settings on app start
        BlocProvider<PreferencesBloc>(
          create: (context) => PreferencesBloc(
            preferencesService: PreferencesService(),
          )..add(LoadPreferencesEvent()), // Load preferences immediately
        ),
        // Photo BLoC - manages photo selection and editing workflow
        BlocProvider<PhotoBloc>(
          create: (context) => PhotoBloc(
            exportService: ExportService(),
          ),
        ),
      ],
      child: BlocBuilder<PreferencesBloc, PreferencesState>(
        builder: (context, state) {
          // Default to system theme mode while preferences are loading
          // This prevents a flash of incorrect theme on app start
          ThemeMode themeMode = ThemeMode.system;
          
          if (state is PreferencesLoadedState) {
            themeMode = state.preferences.themeMode;
          }

          return MaterialApp(
            title: 'InstaFramer',
            debugShowCheckedModeBanner: false,
            // Use FlexColorScheme themes with Material 3 design
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: themeMode, // Respects user's theme preference
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
