import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/photo_settings.dart';

abstract class PhotoState extends Equatable {
  const PhotoState();

  @override
  List<Object?> get props => [];
}

class PhotoInitial extends PhotoState {
  const PhotoInitial();
}

class PhotosLoading extends PhotoState {
  const PhotosLoading();
}

class PhotosLoaded extends PhotoState {
  final List<AssetEntity> photos;
  final PhotoSettings settings;
  final int currentIndex;

  const PhotosLoaded({
    required this.photos,
    required this.settings,
    this.currentIndex = 0,
  });

  @override
  List<Object?> get props => [photos, settings, currentIndex];

  PhotosLoaded copyWith({
    List<AssetEntity>? photos,
    PhotoSettings? settings,
    int? currentIndex,
  }) {
    return PhotosLoaded(
      photos: photos ?? this.photos,
      settings: settings ?? this.settings,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

class PhotosProcessing extends PhotoState {
  final int current;
  final int total;
  final double progress;

  const PhotosProcessing({
    required this.current,
    required this.total,
  }) : progress = current / total;

  @override
  List<Object?> get props => [current, total, progress];
}

class PhotosExported extends PhotoState {
  final int count;

  const PhotosExported(this.count);

  @override
  List<Object?> get props => [count];
}

class PhotoError extends PhotoState {
  final String message;

  const PhotoError(this.message);

  @override
  List<Object?> get props => [message];
}

