import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';

import '../blocs/panorama_bloc/panorama_bloc.dart';
import '../blocs/panorama_bloc/panorama_event.dart';
import '../blocs/panorama_bloc/panorama_state.dart';
import '../models/enums.dart';
import '../models/panorama_settings.dart';
import '../models/panorama_spec.dart';
import '../widgets/editor/control_button.dart';
import '../widgets/editor/editor_app_bar.dart';
import '../widgets/editor/labeled_slider.dart';
import '../widgets/panorama/panorama_fit_mode_toggle.dart';
import '../widgets/panorama/panorama_guide_overlay.dart';
import '../widgets/panorama/panorama_preview.dart';
import '../widgets/panorama/panorama_processing_view.dart';
import '../widgets/panorama/panorama_tile_count_selector.dart';
import 'panorama_instagram_preview_screen.dart';

/// Panorama carousel editor — preview, controls, and export.
///
/// Leaving this screen once a photo is loaded asks for confirmation, same
/// as [EditorScreen] — see `_showLeaveConfirmationDialog`. A pop is disabled
/// entirely while exporting — see [PanoramaProcessingView], which owns its
/// own non-poppable `Scaffold` instead.
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
          // Nothing to lose yet while still loading — only ask once a photo
          // and settings actually exist to discard, mirroring EditorScreen.
          canPop: readyState == null,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) {
              context.read<PanoramaBloc>().add(const ClearPanoramaEvent());
              return;
            }

            final shouldPop = await _showLeaveConfirmationDialog(context);
            if (shouldPop && context.mounted) {
              // Pop before clearing bloc state — clearing first flips
              // `readyState` to null, which flips this same PopScope's
              // `canPop` mid-flight and can cancel the in-flight pop
              // transition, leaving the screen stuck showing the loader
              // until a second back-press. See the `didPop` branch above,
              // which already pops-then-clears for the same reason.
              Navigator.of(context).pop();
              context.read<PanoramaBloc>().add(const ClearPanoramaEvent());
            }
          },
          child: Scaffold(
            appBar: const EditorAppBar(title: 'Panorama Carousel'),
            body: readyState == null
                ? const Center(child: CircularProgressIndicator())
                : _PanoramaReadyView(state: readyState),
          ),
        );
      },
    );
  }

  /// Mirrors `EditorScreen._showLeaveConfirmationDialog` — same prompt shape
  /// and button treatment, so leaving either editor reads as the same
  /// interaction rather than two different patterns for the same risk.
  Future<bool> _showLeaveConfirmationDialog(BuildContext context) async {
    final theme = Theme.of(context);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Leave Panorama Editor?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            "You'll lose your photo and settings if you leave now.",
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'Stay',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text(
                'Leave',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

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

/// The editor's loaded state: preview on top, controls below.
///
/// Stateful only to hold [_isPlacingVertically] — whether the user's finger is
/// currently on the vertical-position slider. That is transient interaction
/// state, not a setting: it never survives the gesture, nothing else reads it,
/// and putting it through `PanoramaBloc` would churn a state emission per
/// drag frame for something the export doesn't care about.
class _PanoramaReadyView extends StatefulWidget {
  final PanoramaReadyState state;

  const _PanoramaReadyView({required this.state});

  @override
  State<_PanoramaReadyView> createState() => _PanoramaReadyViewState();
}

class _PanoramaReadyViewState extends State<_PanoramaReadyView> {
  bool _isPlacingVertically = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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
              child: PanoramaPreview(
                source: state.source,
                settings: settings,
                sourceAspect: state.sourceAspect,
                // Guides earn their place only while something is being
                // placed against them; the rest of the time they are two
                // lines drawn over the user's photo for no reason.
                guidePositions: _isPlacingVertically
                    ? PanoramaGuideOverlay.thirds
                    : const [],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  child: PanoramaTileCountSelector(
                    settings: settings,
                    maxTiles: state.maxTiles,
                    sourceWidth: state.sourceWidth,
                    sourceAspect: state.sourceAspect,
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PanoramaFitModeToggle(fitMode: settings.fitMode),
                      // Fit-only controls animate in/out rather than
                      // snapping, so switching modes reads as a reveal, not
                      // a layout jump.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isFit
                              ? [
                                  const SizedBox(height: 16),
                                  _buildBackgroundSelector(
                                    context,
                                    settings,
                                    state.suggestedColors,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Zoom',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  LabeledSlider(
                                    leadingIcon: Icons.zoom_out,
                                    trailingIcon: Icons.zoom_in,
                                    value: settings.scale,
                                    min: 0.5,
                                    max: 1.0,
                                    // Coarse enough that the segmented track
                                    // (see LabeledSlider) actually reads as
                                    // discrete steps rather than one
                                    // continuous line.
                                    divisions: 10,
                                    valueLabel:
                                        '${(settings.scale * 100).toInt()}%',
                                    onChanged: (value) {
                                      context.read<PanoramaBloc>().add(
                                        UpdatePanoramaScaleEvent(value),
                                      );
                                    },
                                    onChangeEnd: (_) =>
                                        HapticFeedback.selectionClick(),
                                  ),
                                  if (settings.backgroundType ==
                                          BackgroundType.extendedBlur &&
                                      settings.backgroundColor == null)
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
                                  const SizedBox(height: 12),
                                  Text(
                                    'Rounding',
                                    style: theme.textTheme.labelLarge,
                                  ),
                                  LabeledSlider(
                                    leadingIcon: Icons.crop_square_outlined,
                                    trailingIcon: Icons.rounded_corner,
                                    value: settings.cornerRadius,
                                    min: 0.0,
                                    max: 0.3,
                                    divisions: 15,
                                    valueLabel:
                                        '${(settings.cornerRadius * 100).round()}%',
                                    onChanged: (value) {
                                      context.read<PanoramaBloc>().add(
                                        UpdatePanoramaCornerRadiusEvent(value),
                                      );
                                    },
                                    onChangeEnd: (_) =>
                                        HapticFeedback.selectionClick(),
                                  ),
                                ]
                              : [
                                  // Fill's counterpart to the Fit-only block
                                  // above: with no bars to configure, the one
                                  // thing left to decide is which band of the
                                  // photo survives the crop.
                                  const SizedBox(height: 16),
                                  _VerticalPositionControl(
                                    settings: settings,
                                    sourceAspect: state.sourceAspect,
                                    onPlacingChanged: (placing) => setState(() {
                                      _isPlacingVertically = placing;
                                    }),
                                  ),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Seam-nudge stays visible in both modes: it slides the
                // photo within the bars in Fit, and shifts the crop window
                // in Fill. In both, positive means "move the photo right".
                _SectionCard(
                  child: _HorizontalPositionControl(
                    settings: settings,
                    sourceAspect: state.sourceAspect,
                  ),
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
    List<Color> suggestedColors,
  ) {
    // A picked photo color is mutually exclusive with White/Black/Blur, so
    // every pill's `isSelected` also requires no custom color being active —
    // otherwise picking a color would leave e.g. "White" still highlighted.
    final hasCustomColor = settings.backgroundColor != null;

    // Horizontal scroll rather than Wrap: up to 6 suggested-color chips on
    // top of the 3 existing pills can overflow a phone-width row, and a
    // second wrapped line would push every control below it down instead of
    // keeping this section's height stable.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ControlButton(
            icon: Icons.wb_sunny_outlined,
            label: 'White',
            isSelected:
                !hasCustomColor &&
                settings.backgroundType == BackgroundType.white,
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
            isSelected:
                !hasCustomColor &&
                settings.backgroundType == BackgroundType.black,
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
            isSelected:
                !hasCustomColor &&
                settings.backgroundType == BackgroundType.extendedBlur,
            onTap: () {
              context.read<PanoramaBloc>().add(
                const UpdatePanoramaBackgroundTypeEvent(
                  BackgroundType.extendedBlur,
                ),
              );
            },
          ),
          if (suggestedColors.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 40,
              color: Theme.of(context).dividerColor,
            ),
          ],
          for (final color in suggestedColors) ...[
            const SizedBox(width: 8),
            _ColorSwatchButton(
              color: color,
              isSelected: settings.backgroundColor == color,
              onTap: () {
                context.read<PanoramaBloc>().add(
                  UpdatePanoramaBackgroundColorEvent(color),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Success sheet with the numbered tap-order grid — the only place the
  /// reverse-save trick (see `ExportService.exportPanorama`) can be explained
  /// to the user, since the actual carousel assembly happens in Instagram,
  /// outside our control. Rendered as real widgets sized to [tileCount], not
  /// a static image, so it stays correct at every tile count.
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

/// Vertical crop slider — which horizontal band of the photo Fill keeps.
///
/// Fill mode's canvas is usually wider-aspect than the source, so the cover
/// crop throws away the top and bottom. Centring that crop is a guess: a
/// subject sitting high in frame gets its head cut and its feet padded. This
/// is the control that lets the user say where the keeper band is.
///
/// Fill-only by construction — [PanoramaSpec.maxCropOffsetY] returns 0 in Fit,
/// which crops nothing, so the slider would have no travel to offer there.
class _VerticalPositionControl extends StatelessWidget {
  final PanoramaSettings settings;
  final double sourceAspect;

  /// Reports whether a drag is in progress, so the preview can show its
  /// composition guides for exactly as long as they are useful.
  final ValueChanged<bool> onPlacingChanged;

  const _VerticalPositionControl({
    required this.settings,
    required this.sourceAspect,
    required this.onPlacingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxOffset = PanoramaSpec.maxCropOffsetY(
      tileCount: settings.tileCount,
      fitMode: settings.fitMode,
      sourceAspect: sourceAspect,
      canvasRatio: settings.canvasRatio,
    );
    // The source is no taller-aspect than the canvas, so the cover fit crops
    // the sides instead and there is no vertical band to choose between.
    final hasTravel = maxOffset > 0;
    final value = settings.cropOffsetY.clamp(-maxOffset, maxOffset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Vertical position', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          hasTravel
              ? 'Choose which part of the photo the crop keeps.'
              : "Nothing is cropped top or bottom at this tile count, so "
                    "there's nothing to move.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        LabeledSlider(
          // Down-arrow leads because dragging left moves the photo up, which
          // reveals more of the source's bottom — the icons label what the
          // end of the track shows you, not which way the photo travels.
          leadingIcon: Icons.keyboard_arrow_down,
          trailingIcon: Icons.keyboard_arrow_up,
          value: value,
          min: -maxOffset,
          max: maxOffset,
          // Continuous, unlike the app's other sliders: the snap points below
          // are the meaningful stops here, and fixed divisions would compete
          // with them — a stop every 5% that never quite lands on a third.
          divisions: null,
          valueLabel: hasTravel
              ? '${(value / maxOffset * 100).toStringAsFixed(0)}%'
              : '0%',
          onChanged: hasTravel
              ? (raw) {
                  final snapped = PanoramaSpec.snapCropOffsetY(
                    raw,
                    tileCount: settings.tileCount,
                    fitMode: settings.fitMode,
                    sourceAspect: sourceAspect,
                    canvasRatio: settings.canvasRatio,
                  );
                  // Tick only on arrival, not for every frame spent sitting on
                  // a snap point — that is what makes it feel like the control
                  // caught, rather than like a stuck buzz.
                  if (snapped != raw && snapped != settings.cropOffsetY) {
                    HapticFeedback.selectionClick();
                  }
                  context.read<PanoramaBloc>().add(
                    UpdatePanoramaCropOffsetYEvent(snapped),
                  );
                }
              : null,
          onChangeStart: hasTravel ? (_) => onPlacingChanged(true) : null,
          onChangeEnd: (_) {
            onPlacingChanged(false);
            HapticFeedback.selectionClick();
          },
        ),
      ],
    );
  }
}

/// Seam-nudge slider, bounded by the travel the current framing actually
/// allows rather than a fixed ±0.5 tile.
///
/// The bound matters for honesty, not just polish: the photo can only slide
/// as far as the gap between it and the canvas edge, so a fixed range left
/// most of the track inert — dragging it moved the label but not the photo.
/// The label reads as a share of available travel ("-60%" = 60% of the way to
/// the left stop) because the underlying tile-width figure is meaningless
/// without knowing what the stop is.
class _HorizontalPositionControl extends StatelessWidget {
  final PanoramaSettings settings;
  final double sourceAspect;

  const _HorizontalPositionControl({
    required this.settings,
    required this.sourceAspect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxOffset = PanoramaSpec.maxCropOffsetX(
      tileCount: settings.tileCount,
      fitMode: settings.fitMode,
      scale: settings.scale,
      sourceAspect: sourceAspect,
      canvasRatio: settings.canvasRatio,
    );
    // Zero travel: the photo already spans the canvas width, so there is
    // nowhere to nudge it. Say why and how to get the travel back instead of
    // offering a slider that does nothing.
    final hasTravel = maxOffset > 0;
    final value = settings.cropOffsetX.clamp(-maxOffset, maxOffset);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Horizontal position', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          hasTravel
              ? 'Move the photo left or right to choose where the slides '
                    'divide it.'
              : settings.fitMode == PanoramaFitMode.fit
              ? 'The photo already fills the canvas — zoom out to give it '
                    'room to slide.'
              : 'The photo is no wider than the canvas, so there is nothing '
                    'to slide.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        LabeledSlider(
          leadingIcon: Icons.arrow_back,
          trailingIcon: Icons.arrow_forward,
          value: value,
          min: -maxOffset,
          max: maxOffset,
          divisions: 20,
          valueLabel: hasTravel
              ? '${(value / maxOffset * 100).toStringAsFixed(0)}%'
              : '0%',
          onChanged: hasTravel
              ? (value) {
                  context.read<PanoramaBloc>().add(
                    UpdatePanoramaCropOffsetXEvent(value),
                  );
                }
              : null,
          onChangeEnd: (_) => HapticFeedback.selectionClick(),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

/// A solid-color swatch for the photo's suggested background colors — no
/// label, since the color itself is the only information worth showing. The
/// circle is sized up (rather than iconed-and-labelled like [ControlButton])
/// so it reads as a color preview on its own.
class _ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatchButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: theme.dividerColor),
          ),
          child: isSelected
              ? Icon(
                  Icons.check,
                  size: 18,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                          Brightness.light
                      ? Colors.black87
                      : Colors.white,
                )
              : null,
        ),
      ),
    );
  }
}
