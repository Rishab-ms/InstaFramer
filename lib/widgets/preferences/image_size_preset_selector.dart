import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/preferences_bloc/preferences_bloc.dart';
import '../../blocs/preferences_bloc/preferences_event.dart';
import '../../models/image_size.dart';
import 'settings_card.dart';

/// Image size preset selector with radio buttons.
/// 
/// Displays all available image size presets including:
/// - Instagram Portrait/Square/Landscape
/// - High Quality Portrait/Square
/// - Custom dimensions option
/// 
/// Updates PreferencesBloc when selection changes.
class ImageSizePresetSelector extends StatelessWidget {
  /// The currently selected preset
  final ImageSizePreset currentPreset;

  const ImageSizePresetSelector({
    super.key,
    required this.currentPreset,
  });

  void _onPresetChanged(BuildContext context, ImageSizePreset preset) {
    context.read<PreferencesBloc>().add(UpdateImageSizePresetEvent(preset));
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        children: ImageSizePreset.values.asMap().entries.map((entry) {
          final index = entry.key;
          final preset = entry.value;
          final isLast = index == ImageSizePreset.values.length - 1;
          
          return Column(
            children: [
              ListTile(
                title: Text(preset.displayName),
                subtitle: preset == ImageSizePreset.custom
                    ? const Text('Enter custom dimensions below')
                    : Text('${preset.size.width} × ${preset.size.height}'),
                trailing: Radio<ImageSizePreset>(
                  value: preset,
                  groupValue: currentPreset,
                  onChanged: (value) {
                    if (value != null) {
                      _onPresetChanged(context, value);
                    }
                  },
                ),
                onTap: () => _onPresetChanged(context, preset),
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }
}



