import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/photo_settings.dart';
import '../../models/aspect_ratio.dart';
import '../../models/background_type.dart';

/// Base class for all photo-related events.
/// 
/// All PhotoBloc events extend this class and follow the naming convention
/// of ending with "Event" for clarity.
abstract class PhotoEvent extends Equatable {
  const PhotoEvent();

  @override
  List<Object?> get props => [];
}

/// Event to trigger the photo gallery picker.
/// 
/// When dispatched, PhotoBloc transitions to PhotosLoading state
/// and waits for PhotosSelectedEvent to complete the flow.
class LoadPhotosFromGalleryEvent extends PhotoEvent {
  const LoadPhotosFromGalleryEvent();
}

/// Event dispatched when user selects photos from gallery.
/// 
/// Contains the list of selected [AssetEntity] objects (max 30).
/// Triggers validation and transitions to PhotosLoaded state.
class PhotosSelectedEvent extends PhotoEvent {
  final List<AssetEntity> photos;

  const PhotosSelectedEvent(this.photos);

  @override
  List<Object?> get props => [photos];
}

/// Event to update entire PhotoSettings object at once.
/// 
/// Used when multiple settings need to be changed simultaneously.
class UpdatePhotoSettingsEvent extends PhotoEvent {
  final PhotoSettings settings;

  const UpdatePhotoSettingsEvent(this.settings);

  @override
  List<Object?> get props => [settings];
}

/// Event to update only the aspect ratio setting.
/// 
/// Changes between 4:5 portrait and 1:1 square aspect ratios.
class UpdateAspectRatioEvent extends PhotoEvent {
  final AspectRatioType aspectRatio;

  const UpdateAspectRatioEvent(this.aspectRatio);

  @override
  List<Object?> get props => [aspectRatio];
}

/// Event to update the photo scale/zoom level.
/// 
/// Scale ranges from 0.0 (smallest) to 1.0 (fills frame completely).
class UpdateScaleEvent extends PhotoEvent {
  final double scale;

  const UpdateScaleEvent(this.scale);

  @override
  List<Object?> get props => [scale];
}

/// Event to update the background type.
/// 
/// Options: white, black, or extendedBlur background.
class UpdateBackgroundTypeEvent extends PhotoEvent {
  final BackgroundType backgroundType;

  const UpdateBackgroundTypeEvent(this.backgroundType);

  @override
  List<Object?> get props => [backgroundType];
}

/// Event to update the current photo index in the carousel.
/// 
/// Used when user swipes between photos in the editor.
class UpdateCurrentIndexEvent extends PhotoEvent {
  final int index;

  const UpdateCurrentIndexEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Event to trigger batch export of all photos.
/// 
/// Processes all photos with current settings and saves to gallery.
/// Emits PhotosProcessing states with progress updates.
class ExportAllPhotosEvent extends PhotoEvent {
  const ExportAllPhotosEvent();
}

/// Event to clear all photos and reset to initial state.
/// 
/// Used when user cancels selection or wants to start over.
class ClearPhotosEvent extends PhotoEvent {
  const ClearPhotosEvent();
}

