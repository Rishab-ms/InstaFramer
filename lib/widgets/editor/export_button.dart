import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/photo_bloc/photo_bloc.dart';
import '../../blocs/photo_bloc/photo_event.dart';
import '../../blocs/photo_bloc/photo_state.dart';

/// Export button widget for the editor screen.
/// Only rebuilds when photo count changes to prevent unnecessary rebuilds.
class ExportButton extends StatelessWidget {
  const ExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocSelector<PhotoBloc, PhotoState, int>(
      selector: (state) {
        // Only rebuild when photo count changes
        if (state is PhotosLoadedState) {
          return state.photos.length;
        }
        return 0;
      },
      builder: (context, photoCount) {
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
          child: FilledButton.icon(
            onPressed: () {
              // Trigger export event
              context.read<PhotoBloc>().add(const ExportAllPhotosEvent());
            },
            icon: const Icon(Icons.download),
            label: Text('Export All Photos ($photoCount)'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
