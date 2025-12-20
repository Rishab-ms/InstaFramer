import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable card wrapper for settings sections.
/// 
/// Provides consistent spacing and styling for settings groups.
/// Optionally supports highlighted styling for special sections.
class SettingsCard extends StatelessWidget {
  /// The child widget to display inside the card
  final Widget child;
  
  /// Custom background color (overrides isHighlighted)
  final Color? backgroundColor;

  const SettingsCard({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    
    if (backgroundColor != null) {
      cardColor = backgroundColor;
    } else {
      cardColor = Theme.of(context).colorScheme.primaryContainer.withOpacity(0.25);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Card(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        
        child: child,
      ),
    );
  }
}

