import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/photo_settings.dart';
import '../../models/aspect_ratio.dart';
import '../../models/background_type.dart';

abstract class PhotoEvent extends Equatable {
  const PhotoEvent();

  @override
  List<Object?> get props => [];
}

class LoadPhotosFromGallery extends PhotoEvent {
  const LoadPhotosFromGallery();
}

class PhotosSelected extends PhotoEvent {
  final List<AssetEntity> photos;

  const PhotosSelected(this.photos);

  @override
  List<Object?> get props => [photos];
}

class UpdatePhotoSettings extends PhotoEvent {
  final PhotoSettings settings;

  const UpdatePhotoSettings(this.settings);

  @override
  List<Object?> get props => [settings];
}

class UpdateAspectRatio extends PhotoEvent {
  final AspectRatioType aspectRatio;

  const UpdateAspectRatio(this.aspectRatio);

  @override
  List<Object?> get props => [aspectRatio];
}

class UpdateScale extends PhotoEvent {
  final double scale;

  const UpdateScale(this.scale);

  @override
  List<Object?> get props => [scale];
}

class UpdateBackgroundType extends PhotoEvent {
  final BackgroundType backgroundType;

  const UpdateBackgroundType(this.backgroundType);

  @override
  List<Object?> get props => [backgroundType];
}

class UpdateCurrentIndex extends PhotoEvent {
  final int index;

  const UpdateCurrentIndex(this.index);

  @override
  List<Object?> get props => [index];
}

class ExportAllPhotos extends PhotoEvent {
  const ExportAllPhotos();
}

class ClearPhotos extends PhotoEvent {
  const ClearPhotos();
}

