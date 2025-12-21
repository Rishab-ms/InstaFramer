import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/photo_bloc/photo_bloc.dart';
import '../../blocs/photo_bloc/photo_event.dart';
import '../../blocs/photo_bloc/photo_state.dart';
import '../../models/background_type.dart';

/// Export button widget for the editor screen.
/// Only rebuilds when photo count changes to prevent unnecessary rebuilds.
class ExportButton extends StatelessWidget {
  const ExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocSelector<PhotoBloc, PhotoState, ({int photoCount, BackgroundType backgroundType})>(
      selector: (state) {
        // Rebuild when photo count or background type changes
        if (state is PhotosLoadedState) {
          return (
            photoCount: state.photos.length,
            backgroundType: state.settings.backgroundType,
          );
        }
        return (photoCount: 0, backgroundType: BackgroundType.white);
      },
      builder: (context, data) {
        final isBlurBackground = data.backgroundType == BackgroundType.extendedBlur;
        final buttonText = isBlurBackground
            ? 'Export All Photos (${data.photoCount}) - Blur may take longer'
            : 'Export All Photos (${data.photoCount})';

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () {
                  // Trigger export event
                  context.read<PhotoBloc>().add(const ExportAllPhotosEvent());
                },
                icon: const Icon(Icons.download),
                label: Text(buttonText),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isBlurBackground) ...[
                const SizedBox(height: 8),
                Text(
                  'Please wait and do not leave this page during export',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
