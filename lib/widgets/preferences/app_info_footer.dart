import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// App information footer widget.
/// 
/// Displays:
/// - App icon
/// - App name
/// - Version number
/// - Tagline
/// 
/// Centered layout with subtle styling.
class AppInfoFooter extends StatelessWidget {
  /// App name to display
  final String appName;
  
  /// Version string to display
  final String version;
  
  /// Optional tagline text
  final String? tagline;

  const AppInfoFooter({
    super.key,
    this.appName = 'InstaFrame',
    this.version = '1.0.0',
    this.tagline = 'Made with ❤️ in India for Instagram creators',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            appName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingXSmall),
          Text(
            'Version $version',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (tagline != null) ...[
            const SizedBox(height: AppTheme.spacingSmall),
            Text(
              tagline!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

