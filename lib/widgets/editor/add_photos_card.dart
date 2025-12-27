import 'package:flutter/material.dart';

/// Add photos card widget for the carousel.
///
/// Displays a card at the end of the carousel that allows users to add more photos
/// to their selection by navigating back to the photo picker.
class AddPhotosCard extends StatelessWidget {
  /// Callback when the add photos card is tapped
  final VoidCallback onAddPhotos;

  const AddPhotosCard({
    super.key,
    required this.onAddPhotos,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAddPhotos,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 64,
                  color: theme.colorScheme.primary.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Add More Photos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to select additional photos',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



