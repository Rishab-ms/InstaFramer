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

class PhotoCarousel extends StatefulWidget {
  final PhotosLoadedState state;
  final ImageProcessor imageProcessor;

  const PhotoCarousel({
    super.key,
    required this.state,
    required this.imageProcessor,
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
        allowImplicitScrolling: true, // This is now safe to use!
        onIndexChanged: (index) {
          // Only update current index in BLoC if it's not the add photos card
          if (index < widget.state.photos.length) {
            context.read<PhotoBloc>().add(UpdateCurrentIndexEvent(index));
          }
        },
        loop: false,
        scale: 0.95,
        viewportFraction: 0.9,
        itemBuilder: (context, index) {
          if (index == widget.state.photos.length) {
            return AddPhotosCard(
              onAddPhotos: () => _navigateToPhotoPicker(context),
            );
          }

          // We don't need complex viewport logic anymore because
          // PhotoCard is now just lightweight widgets.
          return PhotoCard(
            photoIndex: index,
            photo: widget.state.photos[index],
            settings: widget.state.settings,
            currentIndex: widget.state.currentIndex,
            imageProcessor: widget.imageProcessor,
          );
        },
      ),
    );
  }

  void _navigateToPhotoPicker(BuildContext context) {
    PhotoPickerScreen.pickPhotos(context);
  }
}
