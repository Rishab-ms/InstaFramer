import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_event.dart';
import '../blocs/photo_bloc/photo_state.dart';
import '../models/aspect_ratio.dart' as models;
import '../models/background_type.dart';
import '../services/image_processor.dart';
import '../widgets/editor/editor_app_bar.dart';
import '../widgets/editor/export_button.dart';
import '../widgets/editor/photo_carousel.dart';

/// Editor screen - displays carousel of photos with editing controls.
///
/// This screen is the heart of the app where users:
/// - Swipe through selected photos in a carousel
/// - Adjust aspect ratio (4:5 portrait or 1:1 square)
/// - Control photo scale/zoom (0.0 to 1.0)
/// - Choose background type (white, black, blurred)
/// - Export all photos with current settings
///
/// Uses BLoC pattern to manage state and communicate with PhotoBloc.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  // Image processor for generating previews
  final ImageProcessor _imageProcessor = ImageProcessor();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhotoBloc, PhotoState>(
      // Only listen to state changes for action events (export success/error)
      // Prevents infinite snackbar spam when state rebuilds
      listenWhen: (previous, current) {
        // Only trigger listener when transitioning TO export/error states
        // This ensures snackbar shows exactly once per action
        return (previous is! PhotosExportedState &&
                current is PhotosExportedState) ||
            (previous is! PhotoErrorState && current is PhotoErrorState);
      },

      listener: (context, state) {
        // Show success message when export completes
        if (state is PhotosExportedState) {
          // 1. Haptic Feedback (Optional but nice)
          // HapticFeedback.mediumImpact();

          // 2. Show Success Sheet
          showModalBottomSheet(
            context: context,
            isDismissible: false,
            enableDrag: false,
            useSafeArea: true,
            backgroundColor: Colors.transparent, // Floating look
            builder: (context) => Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'All Done! 🎉',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    '${state.count} photos saved to gallery.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close sheet
                            context.read<PhotoBloc>().add(
                              const ClearPhotosEvent(),
                            );
                            Navigator.of(context).popUntil((r) => r.isFirst);
                          },
                          child: const Text('Home'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Gal.open(), // Open Gallery
                          icon: const Icon(Icons.photo_library),
                          label: const Text('View Photos'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        }

        // Show error messages
        if (state is PhotoErrorState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error: ${state.message}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
      builder: (context, state) {
        // Handle different states
        if (state is PhotosProcessingState) {
          return _buildProcessingView(state,);
        }

        if (state is PhotosLoadedState) {
          return _buildEditorView(context, state);
        }

        // Fallback for unexpected states
        return Scaffold(
          appBar: AppBar(title: const Text('Editor')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  /// Show confirmation dialog when user tries to leave editor.
  ///
  /// Prevents accidental loss of unsaved work by asking for explicit confirmation.
  /// If user confirms, clears BLoC state and allows navigation.
  Future<bool> _showLeaveConfirmationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final photoBloc = context
        .read<PhotoBloc>(); // Store reference before async gap

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Leave Editor?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'You have unsaved changes. Are you sure you want to leave? Your photo selection and settings will be lost.',
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

    // If user confirmed leaving, clear the BLoC state
    if (result == true) {
      photoBloc.add(const ClearPhotosEvent());
    }

    return result ?? false; // Default to false if dialog was dismissed
  }

  /// Build the main editor view with carousel and controls.
  Widget _buildEditorView(BuildContext context, PhotosLoadedState state) {
    final theme = Theme.of(context);
    final settings = state.settings;

    return PopScope(
      canPop: false, // Prevent default back behavior
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          // Show confirmation dialog if pop was prevented
          final shouldPop = await _showLeaveConfirmationDialog(context);
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: const EditorAppBar(),
        body: Column(
          children: [
            // Photo counter above carousel
            BlocSelector<
              PhotoBloc,
              PhotoState,
              ({int currentIndex, int totalPhotos})
            >(
              selector: (state) {
                if (state is PhotosLoadedState) {
                  return (
                    currentIndex: state.currentIndex,
                    totalPhotos: state.photos.length,
                  );
                }
                return (currentIndex: 0, totalPhotos: 0);
              },
              builder: (context, data) {
                return Text(
                  '${data.currentIndex + 1} of ${data.totalPhotos}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Photo carousel (sized to match aspect ratio)
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: settings.aspectRatio.ratio,
                  child: PhotoCarousel(
                    state: state,
                    imageProcessor: _imageProcessor,
                  ),
                ),
              ),
            ),

            // Quick controls with aspect ratio and backgrounds
            _buildQuickControls(context, settings),

            // Scale slider (always visible)
            _buildScaleSlider(context, settings),

            // Blur intensity slider (only shown when blur background is selected)
            if (settings.backgroundType == BackgroundType.extendedBlur)
              _buildBlurIntensitySlider(context, settings),

            // Export button at the bottom
            const ExportButton(),
          ],
        ),
      ),
    );
  }

  /// Build quick controls bar (aspect ratio and background).
  ///
  /// Dynamically generates buttons for all available aspect ratios and
  /// background types. Add new ratios to AspectRatios.all to see them here.
  Widget _buildQuickControls(BuildContext context, dynamic settings) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: IntrinsicHeight(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Aspect ratio selector - dynamically generated
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ...models.AspectRatios.all.map((ratio) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildControlButton(
                          context,
                          icon: _getIconForAspectRatio(ratio.iconName),
                          label: ratio.label,
                          isSelected: settings.aspectRatio.id == ratio.id,
                          onTap: () {
                            context.read<PhotoBloc>().add(
                              UpdateAspectRatioEvent(ratio),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: const VerticalDivider(width: 1),
            ),
            Expanded(
              flex: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Background type selector
                    _buildControlButton(
                      context,
                      icon: Icons.wb_sunny_outlined,
                      label: 'White',
                      isSelected:
                          settings.backgroundType == BackgroundType.white,
                      onTap: () {
                        context.read<PhotoBloc>().add(
                          const UpdateBackgroundTypeEvent(BackgroundType.white),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      context,
                      icon: Icons.nightlight_outlined,
                      label: 'Black',
                      isSelected:
                          settings.backgroundType == BackgroundType.black,
                      onTap: () {
                        context.read<PhotoBloc>().add(
                          const UpdateBackgroundTypeEvent(BackgroundType.black),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildControlButton(
                      context,
                      icon: Icons.blur_on,
                      label: 'Blur',
                      isSelected:
                          settings.backgroundType ==
                          BackgroundType.extendedBlur,
                      onTap: () {
                        context.read<PhotoBloc>().add(
                          const UpdateBackgroundTypeEvent(
                            BackgroundType.extendedBlur,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get IconData from icon name string.
  /// Maps aspect ratio icon names to Material icons.
  IconData _getIconForAspectRatio(String iconName) {
    switch (iconName) {
      case 'crop_portrait':
        return Icons.crop_portrait;
      case 'crop_square':
        return Icons.crop_square;
      case 'crop_landscape':
        return Icons.crop_landscape;
      default:
        return Icons.crop_free;
    }
  }

  /// Build a control button with icon and label.
  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build expanded settings panel with scale slider.
  Widget _buildScaleSlider(BuildContext context, dynamic settings) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.zoom_out,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: settings.scale,
              min: 0.5,
              max: 1.0,
              year2023: false,
              divisions: 50,
              label: '${(settings.scale * 100).toInt()}%',
              onChanged: (value) {
                context.read<PhotoBloc>().add(UpdateScaleEvent(value));
              },
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.zoom_in,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Text(
            '${(settings.scale * 100).toInt()}%',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build blur intensity slider (only shown when blur background is selected).
  Widget _buildBlurIntensitySlider(BuildContext context, dynamic settings) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.blur_circular,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: settings.blurIntensity.toDouble(),
              min: 1,
              max: 100,
              year2023: false,
              divisions: 4, // 5 divisions total
              label: '${settings.blurIntensity}',
              onChanged: (value) {
                context.read<PhotoBloc>().add(
                  UpdateBlurIntensityEvent(value.toInt()),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.blur_on,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 40,
            child: Text(
              '${settings.blurIntensity}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// Build processing view during export.
  Widget _buildProcessingView(
    PhotosProcessingState state,
    
  ) {
    final theme = Theme.of(context);
    // Calculate which photo to show (safe clamp)
  final photoIndex = state.current.clamp(0, state.photos.length - 1);
  final currentPhoto = state.photos[photoIndex];
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. ANIMATED THUMBNAIL
                Expanded(
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The Image
                          AssetEntityImage(
                            currentPhoto,
                            isOriginal: false,
                            thumbnailSize: const ThumbnailSize.square(500),
                            fit: BoxFit.cover,
                          ),
                          // Overlay Darken
                          Container(color: Colors.black45),
                          // Progress Indicator ON TOP of image
                          CircularProgressIndicator(
                            value: state.progress,
                            strokeWidth: 6,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                          // Text ON TOP of image
                          Positioned(
                            bottom: 20,
                            child: Text(
                              '${(state.progress * 100).toInt()}%',
                              style: theme.textTheme.headlineLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 2. TEXT STATUS
                Text(
                  'Polishing Photo ${state.current + 1} of ${state.total}...',
                  style: theme.textTheme.titleMedium,
                ),

                if (state.backgroundType == BackgroundType.extendedBlur) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Applying Blur (Heavy Task) 🎨',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
