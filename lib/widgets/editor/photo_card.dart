import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../services/image_processor.dart';

/// Individual photo card widget for the carousel.
///
/// Displays a single photo with preview processing and viewport optimization.
/// Only processes photos currently in viewport for optimal performance.
class PhotoCard extends StatefulWidget {
  /// Index of this photo in the carousel
  final int photoIndex;

  /// The photo asset entity
  final AssetEntity photo;

  /// Current photo settings
  final dynamic settings;

  /// Current index in the carousel
  final int currentIndex;

  /// Image processor for generating previews
  final ImageProcessor imageProcessor;

  /// Cache for processed preview images
  final Map<String, Uint8List> previewCache;

  const PhotoCard({
    super.key,
    required this.photoIndex,
    required this.photo,
    required this.settings,
    required this.currentIndex,
    required this.imageProcessor,
    required this.previewCache,
  });

  @override
  State<PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<PhotoCard> {
  @override
  Widget build(BuildContext context) {
    final isCurrentPhoto = widget.photoIndex == widget.currentIndex;

    return Card(
      elevation: 0,
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: _buildViewportContent(context, isCurrentPhoto),
    );
  }

  /// Build content for viewport photos, optimizing for cached vs uncached previews.
  Widget _buildViewportContent(BuildContext context, bool isCurrentPhoto) {
    final theme = Theme.of(context);

    // Generate cache key to check if preview is already available
    final scaleRounded = (widget.settings.scale * 100).round();
    final cacheKey =
        '${widget.photoIndex}_${widget.settings.aspectRatio.id}_${scaleRounded}_${widget.settings.backgroundType}_${widget.settings.blurIntensity}_${widget.settings.imageQuality}_${widget.settings.imageSize}';

    // If preview is cached, show it immediately without FutureBuilder
    if (widget.previewCache.containsKey(cacheKey)) {
      return AspectRatio(
        aspectRatio: widget.settings.aspectRatio.ratio,
        child: Image.memory(
          widget.previewCache[cacheKey]!,
          fit: BoxFit.contain,
        ),
      );
    }

    // Preview not cached, use FutureBuilder for async generation
    return FutureBuilder<Uint8List?>(
      future: _generatePreview(widget.photo, widget.settings),
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
                    isCurrentPhoto ? 'Processing preview...' : 'Loading...',
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
          aspectRatio: widget.settings.aspectRatio.ratio,
          child: Image.memory(snapshot.data!, fit: BoxFit.contain),
        );
      },
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
    // Generate cache key based on photo index and all relevant settings
    // Format: "photoIndex_aspectRatioId_scale_backgroundType_blurIntensity_imageQuality_imageSize"
    // Include photo index for proper cache management and priority calculation
    final scaleRounded = (settings.scale * 100)
        .round(); // Convert to percentage (0-100)
    final cacheKey =
        '${widget.photoIndex}_${settings.aspectRatio.id}_${scaleRounded}_${settings.backgroundType}_${settings.blurIntensity}_${settings.imageQuality}_${settings.imageSize}';

    // Return cached preview if available
    if (widget.previewCache.containsKey(cacheKey)) {
      return widget.previewCache[cacheKey]!;
    }

    // Process preview using optimized method (uses thumbnail, not full res)
    final previewBytes = await widget.imageProcessor.processPreview(
      photo,
      settings,
    );

    // Cache the result for instant retrieval on swipe-back
    widget.previewCache[cacheKey] = previewBytes;

    // Smart cache management: maintain optimal size while preserving recent/nearby previews
    _maintainOptimalCacheSize();

    return previewBytes;
  }

  /// Smart cache size management with priority-based eviction.
  /// Maintains optimal cache size while preserving frequently accessed previews.
  void _maintainOptimalCacheSize() {
    const maxCacheSize =
        12; // Slightly larger than before for better performance

    if (widget.previewCache.length <= maxCacheSize) return;

    final currentIndex = widget.currentIndex;

    // Create priority map: higher priority for current position and nearby positions
    final priorityMap = <String, int>{};

    for (final key in widget.previewCache.keys) {
      // Extract photo index from cache key (format: "photoIndex_aspectRatioId_scale_...")
      final parts = key.split('_');
      if (parts.isNotEmpty) {
        try {
          final photoIndex = int.parse(
            parts[0],
          ); // Photo index is now the first part

          // Calculate distance from current carousel position
          final distance = (photoIndex - currentIndex).abs();

          // Priority: current position = 100, adjacent = 50, others = 10
          final priority = distance == 0 ? 100 : (distance == 1 ? 50 : 10);
          priorityMap[key] = priority;
        } catch (_) {
          // If parsing fails, assign low priority
          priorityMap[key] = 1;
        }
      }
    }

    // Sort cache keys by priority (highest first)
    final sortedKeys = priorityMap.keys.toList()
      ..sort((a, b) => priorityMap[b]!.compareTo(priorityMap[a]!));

    // Keep highest priority items, remove others
    final keysToKeep = sortedKeys.take(maxCacheSize).toSet();
    final keysToRemove = widget.previewCache.keys
        .where((key) => !keysToKeep.contains(key))
        .toList();

    for (final key in keysToRemove) {
      widget.previewCache.remove(key);
    }
  }
}
