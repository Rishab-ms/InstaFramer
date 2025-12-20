import 'dart:io';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/photo_settings.dart';
import 'image_processor.dart';

class ExportService {
  final ImageProcessor _imageProcessor;

  ExportService({ImageProcessor? imageProcessor})
      : _imageProcessor = imageProcessor ?? ImageProcessor();

  /// Export all photos with the given settings
  /// Yields progress updates (current photo index)
  Stream<int> exportPhotos({
    required List<AssetEntity> photos,
    required PhotoSettings settings,
  }) async* {
    if (photos.isEmpty) {
      throw Exception('No photos to export');
    }

    // Get temp directory for processing
    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/instaframe_export');
    
    // Create export directory if it doesn't exist
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    try {
      // Process and save each photo
      for (int i = 0; i < photos.length; i++) {
        final asset = photos[i];
        
        // Process the image
        final processedBytes = await _imageProcessor.processImage(
          asset,
          settings,
        );

        // Save to temp file
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final tempFile = File('${exportDir.path}/processed_$timestamp\_$i.jpg');
        await tempFile.writeAsBytes(processedBytes);

        // Save to gallery using gal
        await Gal.putImage(tempFile.path);

        // Delete temp file
        await tempFile.delete();

        // Yield progress
        yield i + 1;
      }
    } finally {
      // Clean up export directory
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
    }
  }

  /// Export a single photo (useful for preview testing)
  Future<String> exportSinglePhoto({
    required AssetEntity photo,
    required PhotoSettings settings,
  }) async {
    final processedBytes = await _imageProcessor.processImage(photo, settings);

    // Get temp directory
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/preview_$timestamp.jpg');
    
    await tempFile.writeAsBytes(processedBytes);
    await Gal.putImage(tempFile.path);
    await tempFile.delete();

    return tempFile.path;
  }
}

