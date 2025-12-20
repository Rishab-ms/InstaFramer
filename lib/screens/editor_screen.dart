import 'dart:typed_data';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gal/gal.dart';
import 'package:photo_manager/photo_manager.dart';

import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_event.dart';
import '../blocs/photo_bloc/photo_state.dart';
import '../models/aspect_ratio.dart' as models;
import '../models/background_type.dart';
import '../screens/preferences_screen.dart';
import '../services/image_processor.dart';

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
  
  // Cache for processed preview images to avoid reprocessing
  // Key: "${photoId}_${aspectRatio}_${scale}_${bgType}_${blurIntensity}"
  final Map<String, Uint8List> _previewCache = {};

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PhotoBloc, PhotoState>(
      // Only listen to state changes for action events (export success/error)
      // Prevents infinite snackbar spam when state rebuilds
      listenWhen: (previous, current) {
        // Only trigger listener when transitioning TO export/error states
        // This ensures snackbar shows exactly once per action
        return (previous is! PhotosExportedState && current is PhotosExportedState) ||
               (previous is! PhotoErrorState && current is PhotoErrorState);
      },
      // Rebuild when state changes to update carousel
      buildWhen: (previous, current) {
        // Clear preview cache when aspect ratio changes
        if (previous is PhotosLoadedState && current is PhotosLoadedState) {
          if (previous.settings.aspectRatio != current.settings.aspectRatio) {
            _previewCache.clear();
          }
        }
        return true;
      },
      listener: (context, state) {
        // Show success message when export completes
        if (state is PhotosExportedState) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Exported ${state.count} photos successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
          
          
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () async {
                  // Open gallery app to view exported photos
                  try {
                    await Gal.open();
                  } catch (e) {
                    // If opening gallery fails, show error
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Could not open gallery: $e'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
          );
          
          // Navigate back to home and clear photos after brief delay
          // This allows the snackbar to be visible for a moment
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && context.mounted) {
              // Clear photos first to reset state
              context.read<PhotoBloc>().add(const ClearPhotosEvent());
              // Then navigate back to home
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
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
          return _buildProcessingView(state);
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

  /// Build the main editor view with carousel and controls.
  Widget _buildEditorView(BuildContext context, PhotosLoadedState state) {
    final theme = Theme.of(context);
    final settings = state.settings;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Edit Photos (${state.currentIndex + 1}/${state.photos.length})'),
        actions: [
          // App preferences/settings navigation
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PreferencesScreen(),
                ),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Photo carousel (sized to match aspect ratio)
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: settings.aspectRatio.ratio,
                child: _buildPhotoCarousel(context, state),
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
          _buildExportButton(context, state.photos.length),
        ],
      ),
    );
  }

  /// Build the photo carousel using card_swiper.
  Widget _buildPhotoCarousel(BuildContext context, PhotosLoadedState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Swiper(
        itemCount: state.photos.length,
        index: state.currentIndex,
        onIndexChanged: (index) {
          // Update current index in BLoC
          context.read<PhotoBloc>().add(UpdateCurrentIndexEvent(index));
        },
        // Swiper configuration for smooth UX
        loop: false,
        scale: 0.95, // Slight scale for depth
        viewportFraction: 0.9, // Show small peek of adjacent cards
        // Use custom pagination for better aesthetics
        pagination: SwiperPagination(
          builder: DotSwiperPaginationBuilder(
            activeColor: Theme.of(context).colorScheme.primary,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            size: 8,
            activeSize: 12,
          ),
        ),
        itemBuilder: (context, index) {
          return _buildPhotoCard(
            context,
            state.photos[index],
            state.settings,
          );
        },
      ),
    );
  }

  /// Build individual photo card with preview.
  ///
  /// Processes the photo with current settings to show accurate preview.
  /// This matches what the exported photo will look like.
  Widget _buildPhotoCard(
    BuildContext context,
    AssetEntity photo,
    dynamic settings,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<Uint8List?>(
        // Process the photo with actual settings for accurate preview
        future: _generatePreview(photo, settings),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show loading state with skeleton
            return Container(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: theme.colorScheme.primary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing preview...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Container(
              color: theme.colorScheme.errorContainer,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Failed to load preview',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Display the processed preview
          // Wrap in AspectRatio to maintain proper dimensions in carousel
          return AspectRatio(
            aspectRatio: settings.aspectRatio.ratio,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
            ),
          );
        },
      ),
    );
  }

  /// Generate a preview of the photo with current settings.
  ///
  /// Uses caching and lower resolution for optimal performance.
  /// Cache key includes all settings that affect the preview appearance.
  Future<Uint8List> _generatePreview(
    AssetEntity photo,
    dynamic settings,
  ) async {
    // Generate cache key based on photo ID and all relevant settings
    final cacheKey = '${photo.id}_${settings.aspectRatio}_${settings.scale.toStringAsFixed(2)}_${settings.backgroundType}_${settings.blurIntensity}';
    
    // Return cached preview if available
    if (_previewCache.containsKey(cacheKey)) {
      return _previewCache[cacheKey]!;
    }
    
    // Process preview using optimized method (uses thumbnail, not full res)
    final previewBytes = await _imageProcessor.processPreview(photo, settings);
    
    // Cache the result for instant retrieval on swipe-back
    _previewCache[cacheKey] = previewBytes;
    
    // Limit cache size to prevent memory issues (keep last 10 previews)
    if (_previewCache.length > 10) {
      // Remove oldest entry (first key)
      _previewCache.remove(_previewCache.keys.first);
    }
    
    return previewBytes;
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
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Aspect ratio selector - dynamically generated
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
            }).toList(),

            const SizedBox(width: 8),
            const VerticalDivider(),
            const SizedBox(width: 8),

            // Background type selector
            _buildControlButton(
              context,
              icon: Icons.wb_sunny_outlined,
              label: 'White',
              isSelected: settings.backgroundType == BackgroundType.white,
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
              isSelected: settings.backgroundType == BackgroundType.black,
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
              isSelected: settings.backgroundType == BackgroundType.extendedBlur,
              onTap: () {
                context.read<PhotoBloc>().add(
                      const UpdateBackgroundTypeEvent(BackgroundType.extendedBlur),
                    );
              },
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
            color: isSelected
                ? theme.colorScheme.primary
                : theme.dividerColor,
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
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
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
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: 1),
        ),
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
              divisions: 99,
              label: '${settings.blurIntensity}',
              onChanged: (value) {
                context.read<PhotoBloc>().add(UpdateBlurIntensityEvent(value.toInt()));
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

  /// Build export button at the bottom.
  Widget _buildExportButton(BuildContext context, int photoCount) {
    final theme = Theme.of(context);

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
  }

  /// Build processing view during export.
  Widget _buildProcessingView(PhotosProcessingState state) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Circular progress indicator
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background circle
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: state.progress,
                      strokeWidth: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  // Percentage text
                  Text(
                    '${(state.progress * 100).toInt()}%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Exporting Photos...',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${state.current} of ${state.total} completed',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // Linear progress bar for additional feedback
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: LinearProgressIndicator(
                value: state.progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

