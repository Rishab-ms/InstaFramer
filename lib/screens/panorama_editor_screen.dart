import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';

import '../blocs/panorama_bloc/panorama_bloc.dart';
import '../blocs/panorama_bloc/panorama_event.dart';
import '../blocs/panorama_bloc/panorama_state.dart';
import '../models/enums.dart';
import '../models/panorama_settings.dart';
import '../widgets/editor/control_button.dart';
import '../widgets/editor/editor_app_bar.dart';
import '../widgets/editor/labeled_slider.dart';
import '../widgets/panorama/panorama_fit_mode_toggle.dart';
import '../widgets/panorama/panorama_preview.dart';
import '../widgets/panorama/panorama_processing_view.dart';
import '../widgets/panorama/panorama_tile_count_selector.dart';
import 'panorama_instagram_preview_screen.dart';

/// Panorama carousel editor — preview, controls, and export.
///
/// Unlike [EditorScreen], leaving this screen has no unsaved-work
/// confirmation: a panorama session is one photo and some sliders, not a
/// batch of picked photos. A normal pop just clears [PanoramaBloc] state.
/// That pop is disabled while exporting — see [PanoramaProcessingView],
/// which owns its own non-poppable `Scaffold` instead.
class PanoramaEditorScreen extends StatelessWidget {
  const PanoramaEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PanoramaBloc, PanoramaState>(
      // Only fire on the transition INTO a terminal state, mirroring
      // EditorScreen's listenWhen — otherwise the success sheet / error
      // snackbar would re-trigger on every unrelated rebuild.
      listenWhen: (previous, current) =>
          (previous is! PanoramaExportedState &&
              current is PanoramaExportedState) ||
          (previous is! PanoramaErrorState && current is PanoramaErrorState),
      listener: (context, state) {
        if (state is PanoramaExportedState) {
          _showSuccessSheet(context, state.tileCount);
        }

        if (state is PanoramaErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
          // The UI decides when to return to `previous` — not a
          // `Future.delayed` cycle inside the bloc. See PanoramaErrorState.
          context.read<PanoramaBloc>().add(const DismissPanoramaErrorEvent());
        }
      },
      builder: (context, state) {
        if (state is PanoramaExportingState) {
          return PanoramaProcessingView(
            phase: state.phase,
            saved: state.saved,
            total: state.total,
          );
        }

        // A fresh PanoramaErrorState still has a ready screen to show behind
        // the snackbar — render `previous` instead of a spinner flash while
        // DismissPanoramaErrorEvent is in flight.
        final readyState = state is PanoramaReadyState
            ? state
            : state is PanoramaErrorState
            ? state.previous
            : null;

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              context.read<PanoramaBloc>().add(const ClearPanoramaEvent());
            }
          },
          child: Scaffold(
            appBar: const EditorAppBar(title: 'Panorama Carousel'),
            body: readyState == null
                ? const Center(child: CircularProgressIndicator())
                : _buildReadyView(context, readyState),
          ),
        );
      },
    );
  }

  Widget _buildReadyView(BuildContext context, PanoramaReadyState state) {
    final theme = Theme.of(context);
    final settings = state.settings;
    final isFit = settings.fitMode == PanoramaFitMode.fit;

    return Column(
      children: [
        // flex: 5/6 rather than "however tall the aspect ratio makes it" —
        // a wide canvas ratio can otherwise render as a sliver at the top of
        // the screen with the rest of the height going to scrollable
        // controls that don't need it. Center+AspectRatio still contains the
        // photo correctly within this budget; a very wide canvas will still
        // look short, because it genuinely is short — this just stops it
        // being *artificially* short too.
        Expanded(
          flex: 5,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: PanoramaPreview(source: state.source, settings: settings),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanoramaTileCountSelector(
                  settings: settings,
                  maxTiles: state.maxTiles,
                  sourceWidth: state.sourceWidth,
                  sourceAspect: state.sourceAspect,
                ),
                const SizedBox(height: 16),
                PanoramaFitModeToggle(fitMode: settings.fitMode),
                // Fit-only controls animate in/out rather than snapping, so
                // switching modes reads as a reveal, not a layout jump.
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: isFit
                        ? [
                            const SizedBox(height: 16),
                            _buildBackgroundSelector(context, settings),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Zoom', style: theme.textTheme.labelLarge),
                                const Spacer(),
                                if (settings.scale !=
                                    PanoramaSettings.defaultScale)
                                  _ResetButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      context.read<PanoramaBloc>().add(
                                        const ResetPanoramaScaleEvent(),
                                      );
                                    },
                                  ),
                              ],
                            ),
                            LabeledSlider(
                              leadingIcon: Icons.zoom_out,
                              trailingIcon: Icons.zoom_in,
                              value: settings.scale,
                              min: 0.5,
                              max: 1.0,
                              // Coarse enough that the segmented track (see
                              // LabeledSlider) actually reads as discrete
                              // steps rather than one continuous line.
                              divisions: 10,
                              valueLabel: '${(settings.scale * 100).toInt()}%',
                              onChanged: (value) {
                                context.read<PanoramaBloc>().add(
                                  UpdatePanoramaScaleEvent(value),
                                );
                              },
                              onChangeEnd: (_) =>
                                  HapticFeedback.selectionClick(),
                            ),
                            if (settings.backgroundType ==
                                BackgroundType.extendedBlur)
                              LabeledSlider(
                                leadingIcon: Icons.blur_circular,
                                trailingIcon: Icons.blur_on,
                                value: settings.blurIntensity.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 4,
                                valueLabel: '${settings.blurIntensity}',
                                onChanged: (value) {
                                  context.read<PanoramaBloc>().add(
                                    UpdatePanoramaBlurIntensityEvent(
                                      value.toInt(),
                                    ),
                                  );
                                },
                                onChangeEnd: (_) =>
                                    HapticFeedback.selectionClick(),
                              ),
                          ]
                        : const [],
                  ),
                ),
                const SizedBox(height: 16),
                // Seam-nudge stays visible in both modes: it slides the
                // photo within the bars in Fit, and shifts the crop window
                // in Fill.
                Row(
                  children: [
                    Text('Seam position', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    _SeamOffsetBadge(isManual: settings.seamOffsetIsManual),
                    const Spacer(),
                    if (settings.seamOffsetIsManual)
                      _ResetButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          context.read<PanoramaBloc>().add(
                            const ResetPanoramaSeamOffsetEvent(),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Nudge to keep faces or straight edges off the cut lines.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                LabeledSlider(
                  leadingIcon: Icons.arrow_back,
                  trailingIcon: Icons.arrow_forward,
                  value: settings.seamOffset,
                  min: -0.5,
                  max: 0.5,
                  divisions: 20,
                  valueLabel:
                      '${(settings.seamOffset * 100).toStringAsFixed(0)}%',
                  onChanged: (value) {
                    context.read<PanoramaBloc>().add(
                      UpdatePanoramaSeamOffsetEvent(value),
                    );
                  },
                  onChangeEnd: (_) => HapticFeedback.selectionClick(),
                ),
              ],
            ),
          ),
        ),
        // Fixed footer, not part of the scrolling column — this is the
        // primary action and must stay reachable without scrolling, however
        // many controls are expanded above it. Exporting itself happens one
        // screen further in, from the preview — see _openInstagramPreview.
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: FilledButton.icon(
                onPressed: () => _openInstagramPreview(context, state),
                icon: const Icon(Icons.smartphone),
                label: const Text('Preview'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openInstagramPreview(BuildContext context, PanoramaReadyState state) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PanoramaInstagramPreviewScreen(
          source: state.source,
          settings: state.settings,
        ),
      ),
    );
  }

  Widget _buildBackgroundSelector(
    BuildContext context,
    PanoramaSettings settings,
  ) {
    return Row(
      children: [
        ControlButton(
          icon: Icons.wb_sunny_outlined,
          label: 'White',
          isSelected: settings.backgroundType == BackgroundType.white,
          onTap: () {
            context.read<PanoramaBloc>().add(
              const UpdatePanoramaBackgroundTypeEvent(BackgroundType.white),
            );
          },
        ),
        const SizedBox(width: 8),
        ControlButton(
          icon: Icons.nightlight_outlined,
          label: 'Black',
          isSelected: settings.backgroundType == BackgroundType.black,
          onTap: () {
            context.read<PanoramaBloc>().add(
              const UpdatePanoramaBackgroundTypeEvent(BackgroundType.black),
            );
          },
        ),
        const SizedBox(width: 8),
        ControlButton(
          icon: Icons.blur_on,
          label: 'Blur',
          isSelected: settings.backgroundType == BackgroundType.extendedBlur,
          onTap: () {
            context.read<PanoramaBloc>().add(
              const UpdatePanoramaBackgroundTypeEvent(
                BackgroundType.extendedBlur,
              ),
            );
          },
        ),
      ],
    );
  }

  /// Success sheet with the numbered tap-order grid — the only place the
  /// reverse-save trick (see `ExportService.exportPanorama`) can be explained
  /// to the user, since the actual carousel assembly happens in Instagram,
  /// outside our control. Rendered as real widgets sized to [tileCount], not
  /// a static image, so it stays correct at every tile count.
  void _showSuccessSheet(BuildContext context, int tileCount) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text('All Done! 🎉', style: theme.textTheme.headlineSmall),
              Text(
                '$tileCount tiles saved to gallery.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      "In Instagram, tap them left to right — they're "
                      'already in the right order.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    _TapOrderGrid(tileCount: tileCount),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext); // Close sheet
                        context.read<PanoramaBloc>().add(
                          const ClearPanoramaEvent(),
                        );
                        Navigator.of(context).popUntil((r) => r.isFirst);
                      },
                      child: const Text('Home'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Gal.open(),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('View Photos'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

/// Renders [tileCount] numbered squares in save/tap order — the picture the
/// success sheet's copy is describing.
class _TapOrderGrid extends StatelessWidget {
  final int tileCount;

  const _TapOrderGrid({required this.tileCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grid = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(tileCount, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${i + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );

    // At the max 10 tiles this row can get tight on narrow phones — scroll
    // instead of clipping, but stay centred (via the minWidth constraint)
    // for the common case where it fits comfortably.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: grid,
          ),
        );
      },
    );
  }
}

/// Badge next to the seam-position label, distinguishing a starting seam
/// (picked by a plain contrast-detection heuristic, see
/// `PanoramaSeams.bestSeamOffset`) from one the user has manually nudged —
/// otherwise the slider looks the same whether it moved itself or not.
///
/// Copy deliberately avoids "auto"/"AI" framing — this is a simple edge-
/// detection formula, not a model, and the wording shouldn't overclaim.
class _SeamOffsetBadge extends StatelessWidget {
  final bool isManual;

  const _SeamOffsetBadge({required this.isManual});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isManual
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isManual ? Icons.tune : Icons.lightbulb_outline,
            size: 12,
            color: isManual
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            isManual ? 'Custom' : 'Suggested',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isManual
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact "Reset" affordance shown next to a slider's label once its value
/// has drifted from the default — absent otherwise, so there's nothing to
/// tap (or explain) when a reset would be a no-op.
class _ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.replay, size: 18),
      tooltip: 'Reset',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}
