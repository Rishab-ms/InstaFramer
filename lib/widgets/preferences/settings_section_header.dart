import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable section header for settings screens.
/// 
/// Displays a title with optional description text below it.
/// Styled with primary color and consistent spacing.
class SettingsSectionHeader extends StatelessWidget {
  /// The section title text
  final String title;
  
  /// Optional description text shown below the title
  final String? description;

  const SettingsSectionHeader({
    super.key,
    required this.title,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
        AppTheme.spacingMedium,
        AppTheme.spacingSmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: AppTheme.spacingXSmall),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


