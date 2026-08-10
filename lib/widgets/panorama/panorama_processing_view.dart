import 'package:flutter/material.dart';

import '../../models/enums.dart';

/// Two-phase progress view shown while a panorama exports.
///
/// `rendering` is indeterminate. The single `processPanorama` isolate call
/// must finish in full before any tile exists to report progress on, so a
/// naive percentage would sit at 0% then jump. `saving` is determinate, one
/// tick per tile committed to the gallery. `PopScope(canPop: false)` mirrors
/// the framer's processing view. Exporting is not interruptible.
class PanoramaProcessingView extends StatelessWidget {
  final PanoramaExportPhase phase;
  final int saved;
  final int total;

  const PanoramaProcessingView({
    super.key,
    required this.phase,
    required this.saved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRendering = phase == PanoramaExportPhase.rendering;
    final progress = total == 0 ? 0.0 : saved / total;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TileStrip(total: total, theme: theme),
                const SizedBox(height: 40),
                if (isRendering) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Rendering panorama…',
                    style: theme.textTheme.titleMedium,
                  ),
                ] else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saving tile $saved of $total  ·  '
                    '${(progress * 100).toInt()}%',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  "Don't leave this page",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Camera and location info isn't preserved in panorama "
                  'tiles.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

/// Decorative stand-in for the canvas, [total] faint tiles, not a live
/// render of the photo. [PanoramaExportingState] deliberately carries no
/// `source`/`settings`, so this view has nothing to render the real preview
/// from.
class _TileStrip extends StatelessWidget {
  final int total;
  final ThemeData theme;

  const _TileStrip({required this.total, required this.theme});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: total * 0.8,
      child: Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
          );
        }),
      ),
    );
  }
}
