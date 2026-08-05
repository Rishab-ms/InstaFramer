import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
import '../widgets/panorama/panorama_tile_count_selector.dart';

/// Panorama carousel editor — preview plus controls, preview-only until
/// Step 3 wires up export.
///
/// Unlike [EditorScreen], leaving this screen has no unsaved-work
/// confirmation: a panorama session is one photo and some sliders, not a
/// batch of picked photos. A normal pop just clears [PanoramaBloc] state.
class PanoramaEditorScreen extends StatelessWidget {
  const PanoramaEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<PanoramaBloc>().add(const ClearPanoramaEvent());
        }
      },
      child: Scaffold(
        appBar: const EditorAppBar(title: 'Panorama Carousel'),
        body: BlocBuilder<PanoramaBloc, PanoramaState>(
          builder: (context, state) {
            if (state is! PanoramaReadyState) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildReadyView(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildReadyView(BuildContext context, PanoramaReadyState state) {
    final settings = state.settings;
    final isFit = settings.fitMode == PanoramaFitMode.fit;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: PanoramaPreview(source: state.source, settings: settings),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PanoramaTileCountSelector(
                  tileCount: settings.tileCount,
                  maxTiles: state.maxTiles,
                  sourceAspect: state.sourceAspect,
                  fitMode: settings.fitMode,
                ),
                const SizedBox(height: 16),
                PanoramaFitModeToggle(fitMode: settings.fitMode),
                const SizedBox(height: 16),
                if (isFit) ...[
                  _buildBackgroundSelector(context, settings),
                  const SizedBox(height: 12),
                  LabeledSlider(
                    leadingIcon: Icons.zoom_out,
                    trailingIcon: Icons.zoom_in,
                    value: settings.scale,
                    min: 0.5,
                    max: 1.0,
                    divisions: 50,
                    valueLabel: '${(settings.scale * 100).toInt()}%',
                    onChanged: (value) {
                      context.read<PanoramaBloc>().add(
                        UpdatePanoramaScaleEvent(value),
                      );
                    },
                  ),
                  if (settings.backgroundType == BackgroundType.extendedBlur)
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
                          UpdatePanoramaBlurIntensityEvent(value.toInt()),
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                ],
                // Seam-nudge stays visible in both modes: it slides the
                // photo within the bars in Fit, and shifts the crop window
                // in Fill.
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
                ),
                const SizedBox(height: 20),
                // Export is wired in Step 3.
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.ios_share),
                  label: Text('Export ${settings.tileCount} tiles'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
}
