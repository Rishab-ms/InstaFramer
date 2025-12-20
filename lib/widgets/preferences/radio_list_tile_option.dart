import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable radio list tile for selectable options.
/// 
/// Provides a consistent interface for radio button selections
/// with icon, title, subtitle, and haptic feedback.
class RadioListTileOption<T> extends StatelessWidget {
  /// The value this tile represents
  final T value;
  
  /// The currently selected value
  final T groupValue;
  
  /// Callback when the tile is selected
  final ValueChanged<T> onChanged;
  
  /// Icon to display on the left
  final IconData icon;
  
  /// Main title text
  final String title;
  
  /// Subtitle text shown below the title
  final String subtitle;

  const RadioListTileOption({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  void _handleTap() {
    onChanged(value);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: (_) => _handleTap(),
      ),
      onTap: _handleTap,
    );
  }
}

