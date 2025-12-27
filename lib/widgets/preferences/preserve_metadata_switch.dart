import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/preferences_bloc/preferences_bloc.dart';
import '../../blocs/preferences_bloc/preferences_event.dart';
import '../../theme/app_theme.dart';
import 'settings_card.dart';

/// Switch control for metadata preservation setting.
/// Allows users to choose whether to preserve EXIF data from original images.
class PreserveMetadataSwitch extends StatelessWidget {
  /// Current state of metadata preservation
  final bool preserveMetadata;

  const PreserveMetadataSwitch({
    super.key,
    required this.preserveMetadata,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: SwitchListTile(
        title: const Text('Preserve Photo Metadata'),
        subtitle: const Text(
          'Keep original date, location, and camera information in exported photos'
        ),
        value: preserveMetadata,
        onChanged: (bool value) {
          // Dispatch event to update setting
          context.read<PreferencesBloc>().add(UpdatePreserveMetadataEvent(value));
        },
        activeColor: Theme.of(context).colorScheme.primaryContainer,
        inactiveThumbColor: Theme.of(context).colorScheme.onSurfaceVariant,
        inactiveTrackColor: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge,
          vertical: AppTheme.spacingSmall,
        ),
      ),
    );
  }
}


