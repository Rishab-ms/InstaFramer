import 'dart:typed_data';
import 'package:card_swiper/card_swiper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/photo_bloc/photo_bloc.dart';
import '../../blocs/photo_bloc/photo_event.dart';
import '../../blocs/photo_bloc/photo_state.dart';
import '../../screens/photo_picker_screen.dart';
import '../../services/image_processor.dart';
import 'add_photos_card.dart';
import 'photo_card.dart';

/// Photo carousel widget for displaying and navigating through selected photos.
///
/// Displays photos in a swipeable carousel with viewport optimization for performance.
/// Only processes photos currently in viewport to avoid unnecessary processing.
class PhotoCarousel extends StatefulWidget {
  /// The current state containing photos and settings
  final PhotosLoadedState state;

  /// Image processor for generating previews
  final ImageProcessor imageProcessor;

  /// Cache for processed preview images
  final Map<String, Uint8List> previewCache;

  const PhotoCarousel({
    super.key,
    required this.state,
    required this.imageProcessor,
    required this.previewCache,
  });

  @override
  State<PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<PhotoCarousel> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Swiper(
        itemCount: widget.state.photos.length + 1, // +1 for add photos card
        index: widget.state.currentIndex,
        fade: 0.5,
        allowImplicitScrolling: true,
        onIndexChanged: (index) {
          // Only update current index in BLoC if it's not the add photos card
          if (index < widget.state.photos.length) {
            context.read<PhotoBloc>().add(UpdateCurrentIndexEvent(index));
          }
        },
        // Swiper configuration for smooth UX
        loop: false,
        scale: 0.95, // Slight scale for depth
        viewportFraction: 0.9, // Show small peek of adjacent cards
        itemBuilder: (context, index) {
          // Check if this is the add photos card (last item)
          if (index == widget.state.photos.length) {
            return AddPhotosCard(
              onAddPhotos: () => _navigateToPhotoPicker(context),
            );
          }

          // Regular photo card
          return PhotoCard(
            photoIndex: index,
            photo: widget.state.photos[index],
            settings: widget.state.settings,
            currentIndex: widget.state.currentIndex,
            imageProcessor: widget.imageProcessor,
            previewCache: widget.previewCache,
          );
        },
      ),
    );
  }

  /// Navigate to photo picker to add more photos.
  ///
  /// Launches the photo picker dialog and handles the selection.
  /// If photos are selected, they will be added to the existing selection.
  void _navigateToPhotoPicker(BuildContext context) {
    PhotoPickerScreen.pickPhotos(context);
  }

}
