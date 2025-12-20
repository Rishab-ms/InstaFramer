import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../models/photo_settings.dart';

/// Base class for all photo-related states.
/// 
/// All PhotoBloc states extend this class and follow the naming convention
/// of ending with "State" for clarity.
abstract class PhotoState extends Equatable {
  const PhotoState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any photos are selected.
/// 
/// This is the default state when the app starts or after [ClearPhotosEvent].
class PhotoInitialState extends PhotoState {
  const PhotoInitialState();
}

/// Loading state while photo picker is active.
/// 
/// Transitions to this state when [LoadPhotosFromGalleryEvent] is dispatched.
/// Shows loading indicator in UI until [PhotosSelectedEvent] completes.
class PhotosLoadingState extends PhotoState {
  const PhotosLoadingState();
}

/// Main editing state when photos are loaded and ready for editing.
/// 
/// Contains:
/// - [photos]: List of selected AssetEntity objects (1-30 photos)
/// - [settings]: Current PhotoSettings (aspect ratio, scale, background)
/// - [currentIndex]: Current photo index in carousel (0-based)
class PhotosLoadedState extends PhotoState {
  final List<AssetEntity> photos;
  final PhotoSettings settings;
  final int currentIndex;

  const PhotosLoadedState({
    required this.photos,
    required this.settings,
    this.currentIndex = 0,
  });

  @override
  List<Object?> get props => [photos, settings, currentIndex];

  /// Create a copy of this state with updated fields.
  /// Used for immutable state updates in BLoC.
  PhotosLoadedState copyWith({
    List<AssetEntity>? photos,
    PhotoSettings? settings,
    int? currentIndex,
  }) {
    return PhotosLoadedState(
      photos: photos ?? this.photos,
      settings: settings ?? this.settings,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

/// Processing state during batch export.
/// 
/// Emitted during [ExportAllPhotosEvent] to show export progress.
/// [progress] is automatically calculated as current/total (0.0 to 1.0).
class PhotosProcessingState extends PhotoState {
  final int current;
  final int total;
  final double progress;

  const PhotosProcessingState({
    required this.current,
    required this.total,
  }) : progress = current / total;

  @override
  List<Object?> get props => [current, total, progress];
}

/// Success state after all photos are exported.
/// 
/// Shows completion message with [count] of exported photos.
/// Automatically transitions back to [PhotosLoadedState] after 2 seconds.
class PhotosExportedState extends PhotoState {
  final int count;

  const PhotosExportedState(this.count);

  @override
  List<Object?> get props => [count];
}

/// Error state when something goes wrong.
/// 
/// Contains error [message] to display to user.
/// Can occur during photo selection, processing, or export.
class PhotoErrorState extends PhotoState {
  final String message;

  const PhotoErrorState(this.message);

  @override
  List<Object?> get props => [message];
}

