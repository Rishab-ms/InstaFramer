import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Error state view for displaying error messages.
/// 
/// Shows:
/// - Error icon
/// - Title text
/// - Error message
/// 
/// Used when preferences fail to load or other errors occur.
class ErrorStateView extends StatelessWidget {
  /// The error message to display
  final String message;
  
  /// Optional title (defaults to 'Failed to load settings')
  final String? title;

  const ErrorStateView({
    super.key,
    required this.message,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppTheme.spacingMedium),
            Text(
              title ?? 'Failed to load settings',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


