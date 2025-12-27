import 'package:flutter/material.dart';

/// Simple placeholder widget for photos not in viewport.
///
/// This is a lightweight alternative to PhotoCard for non-viewport photos
/// that avoids expensive state management and async operations.
class SimplePhotoPlaceholder extends StatelessWidget {
  /// Index of this photo in the carousel
  final int photoIndex;

  /// Current carousel index
  final int currentIndex;

  /// Current aspect ratio for proper sizing
  final double aspectRatio;

  const SimplePhotoPlaceholder({
    super.key,
    required this.photoIndex,
    required this.currentIndex,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 8),
                Text(
                  'Photo ${photoIndex + 1}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Swipe to preview',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


