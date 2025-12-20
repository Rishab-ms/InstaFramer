import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable card wrapper for settings sections.
/// 
/// Provides consistent spacing and styling for settings groups.
/// Optionally supports highlighted styling for special sections.
class SettingsCard extends StatelessWidget {
  /// The child widget to display inside the card
  final Widget child;
  
  /// Whether to apply highlighted styling (colored background)
  final bool isHighlighted;
  
  /// Custom background color (overrides isHighlighted)
  final Color? backgroundColor;

  const SettingsCard({
    super.key,
    required this.child,
    this.isHighlighted = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    Color? cardColor;
    
    if (backgroundColor != null) {
      cardColor = backgroundColor;
    } else if (isHighlighted) {
      cardColor = Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5);
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
      child: Card(
        color: cardColor,
        elevation: isHighlighted ? 0 : null,
        child: child,
      ),
    );
  }
}

