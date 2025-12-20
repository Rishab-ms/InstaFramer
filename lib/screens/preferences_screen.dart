import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/preferences_bloc/preferences_bloc.dart';
import '../blocs/preferences_bloc/preferences_state.dart';
import '../models/image_size.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';
import '../widgets/preferences/app_info_footer.dart';
import '../widgets/preferences/custom_size_input_card.dart';
import '../widgets/preferences/error_state_view.dart';
import '../widgets/preferences/feedback_tile.dart';
import '../widgets/preferences/image_size_preset_selector.dart';
import '../widgets/preferences/quality_slider_card.dart';
import '../widgets/preferences/settings_section_header.dart';
import '../widgets/preferences/theme_mode_selector.dart';

/// Preferences screen displaying app settings and configuration options.
///
/// Features:
/// - Theme mode selection (System/Light/Dark)
/// - Image quality slider (1-100%)
/// - Image size presets with custom dimension inputs
/// - Feedback email composition with auto-populated device info
///
/// All settings are persisted to SharedPreferences and take effect immediately.
/// 
/// This screen uses reusable widget components for maintainability and consistency.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  
  // Controllers for custom image size inputs
  final TextEditingController _widthController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// Sync text controllers with current preferences when custom preset is selected
  void _syncControllersWithState(PreferencesLoadedState state) {
    if (state.preferences.imageSizePreset == ImageSizePreset.custom) {
      final customSize = state.preferences.customImageSize;
      _widthController.text = customSize.width.toString();
      _heightController.text = customSize.height.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: BlocBuilder<PreferencesBloc, PreferencesState>(
        builder: (context, state) {
          // Loading state
          if (state is PreferencesLoadingState) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Error state
          if (state is PreferencesErrorState) {
            return ErrorStateView(message: state.message);
          }
          
          // Empty state (shouldn't happen but handle gracefully)
          if (state is! PreferencesLoadedState) {
            return const SizedBox.shrink();
          }
          
          final preferences = state.preferences;
          
          // Sync controllers with current preferences
          _syncControllersWithState(state);
          
          return _buildSettingsList(context, state, preferences);
        },
      ),
    );
  }

  /// Builds the main settings list with all sections
  Widget _buildSettingsList(
    BuildContext context,
    PreferencesLoadedState state,
    preferences,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMedium),
      children: [
        // Appearance Section
        const SettingsSectionHeader(title: 'Appearance'),
        ThemeModeSelector(currentMode: preferences.themeMode),
        const Divider(height: AppTheme.spacingLarge * 2),
        
        // Export Quality Section
        const SettingsSectionHeader(title: 'Export Quality'),
        QualitySliderCard(currentQuality: preferences.imageQuality),
        const Divider(height: AppTheme.spacingLarge * 2),
        
        // Export Size Section
        const SettingsSectionHeader(title: 'Export Size'),
        ImageSizePresetSelector(currentPreset: preferences.imageSizePreset),
        
        // Custom size input (conditionally shown)
        if (preferences.imageSizePreset == ImageSizePreset.custom)
          CustomSizeInputCard(
            widthController: _widthController,
            heightController: _heightController,
          ),
        
        const Divider(height: AppTheme.spacingLarge * 2),
        
        // Support Section
        const SettingsSectionHeader(title: 'Support'),
        FeedbackTile(feedbackService: _feedbackService),
        
        // App Info Footer
        const SizedBox(height: AppTheme.spacingXLarge),
        const AppInfoFooter(),
      ],
    );
  }
}
