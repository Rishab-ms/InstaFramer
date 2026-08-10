import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../blocs/panorama_bloc/panorama_bloc.dart';
import '../../blocs/panorama_bloc/panorama_event.dart';
import '../../blocs/photo_bloc/photo_bloc.dart';
import '../../blocs/photo_bloc/photo_event.dart';
import '../../models/panorama_spec.dart';
import '../../screens/panorama_editor_screen.dart';

/// Suggests the panorama flow when a single wide photo is loaded into the
/// framer.
///
/// Today, loading a very wide photo into the framer and picking 4:5
/// produces a tiny strip marooned in white — a genuinely bad result with no
/// hint that a better tool is two taps away. This banner is the discovery
/// path for people who never notice the Home-screen button.
///
/// Dismissal is local widget state, not persisted — a per-photo suggestion
/// isn't worth a preferences key. The caller keys this widget by photo id
/// (see `editor_screen.dart`), so a different single photo gets a fresh,
/// un-dismissed banner.
class PanoramaSuggestionBanner extends StatefulWidget {
  final AssetEntity photo;

  const PanoramaSuggestionBanner({super.key, required this.photo});

  @override
  State<PanoramaSuggestionBanner> createState() =>
      _PanoramaSuggestionBannerState();
}

class _PanoramaSuggestionBannerState extends State<PanoramaSuggestionBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final suggestedTiles = PanoramaSpec.evaluate(
      sourceWidth: widget.photo.orientatedWidth,
      sourceHeight: widget.photo.orientatedHeight,
    ).suggestedTiles;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.panorama_horizontal_outlined,
            color: theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This photo is very wide. Split it into a $suggestedTiles-tile '
              'carousel instead?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Dispatched before the route replacement, not awaited — the
              // eligibility check that gates this banner's visibility is the
              // same PanoramaSpec.evaluate the bloc re-runs, so it's already
              // known to land in PanoramaReadyState. PanoramaEditorScreen
              // shows a brief spinner for the gap while it does.
              context.read<PanoramaBloc>().add(
                PanoramaSourceSelectedEvent(widget.photo),
              );
              context.read<PhotoBloc>().add(const ClearPhotosEvent());
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const PanoramaEditorScreen()),
              );
            },
            child: const Text('Try it'),
          ),
          IconButton(
            icon: Icon(
              Icons.close,
              size: 18,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _dismissed = true),
          ),
        ],
      ),
    );
  }
}
