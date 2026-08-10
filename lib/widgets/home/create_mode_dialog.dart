import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../blocs/photo_bloc/photo_bloc.dart';
import '../../blocs/photo_bloc/photo_event.dart';
import '../../models/enums.dart';
import '../../models/panorama_spec.dart';

/// Mode picker shown for a fresh single-photo share that's panorama-eligible
///. See `SharedPhotoModeSelectionState`.
///
/// `barrierDismissible: false` + `PopScope(canPop: false)`: the shared photo
/// is already copied into the gallery by the time this appears
/// (`saveImageWithPath` runs during import), so an accidental dismissal
/// would leave the share unacknowledged with no way back to it. Cancel is
/// the explicit way out instead.
class CreateModeDialog extends StatelessWidget {
  final AssetEntity photo;

  const CreateModeDialog({super.key, required this.photo});

  static Future<void> show(BuildContext context, AssetEntity photo) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateModeDialog(photo: photo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Re-running evaluate() here is cheap (pure arithmetic on dimensions,
    // no isolate) and keeps eligibility in one place. This dialog only
    // shows when it already returned eligible, so suggestedTiles is the
    // only field needed from it.
    final suggestedTiles = PanoramaSpec.evaluate(
      sourceWidth: photo.orientatedWidth,
      sourceHeight: photo.orientatedHeight,
      tileRatio: PanoramaTileRatio.portrait.ratio,
    ).suggestedTiles;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('One photo shared'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'What do you want to make?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _ModeOption(
              icon: Icons.image_outlined,
              title: 'Framed Photo',
              subtitle: 'Fit to 4:5 with a background',
              onTap: () {
                // Close the dialog before dispatching. HomeScreen's
                // PhotoBloc listener pushes EditorScreen on the resulting
                // PhotosLoadedState, and that push must land on top of an
                // already-popped dialog route, not underneath a lingering
                // one (see the panorama success sheet for the same pattern).
                Navigator.pop(context);
                context.read<PhotoBloc>().add(PhotosSelectedEvent([photo]));
              },
            ),
            const SizedBox(height: 8),
            _ModeOption(
              icon: Icons.panorama_horizontal_outlined,
              title: 'Panorama Carousel',
              subtitle: 'Split into $suggestedTiles tiles',
              onTap: () {
                Navigator.pop(context);
                context.read<PanoramaBloc>().add(
                  PanoramaSourceSelectedEvent(photo),
                );
                context.read<PhotoBloc>().add(const ClearPhotosEvent());
              },
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<PhotoBloc>().add(const ClearPhotosEvent());
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _ModeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
