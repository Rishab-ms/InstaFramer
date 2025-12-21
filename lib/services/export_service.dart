import 'dart:io';
import 'dart:developer';
import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../models/photo_settings.dart';
import 'image_processor.dart';

class ExportService {
  final ImageProcessor _imageProcessor;

  ExportService({ImageProcessor? imageProcessor})
      : _imageProcessor = imageProcessor ?? ImageProcessor();

  int _calculateAdaptiveBatchSize() {
    // 3 is a safe balance for typical 12MP images on modern phones.
    return 3; 
  }

  Stream<int> exportPhotos({
    required List<AssetEntity> photos,
    required PhotoSettings settings,
    required bool preserveMetadata,
  }) async* {
    if (photos.isEmpty) throw Exception('No photos to export');

    final tempDir = await getTemporaryDirectory();
    final exportDir = Directory('${tempDir.path}/instaframe_export');
    if (!await exportDir.exists()) await exportDir.create(recursive: true);

    try {
      final batchSize = _calculateAdaptiveBatchSize();
      var completedCount = 0;

      for (var batchStart = 0; batchStart < photos.length; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize).clamp(0, photos.length);
        final batch = photos.sublist(batchStart, batchEnd);

        final batchFutures = batch.asMap().entries.map((entry) async {
          final index = entry.key;
          final asset = entry.value;
          final globalIndex = batchStart + index;

          // OPTIMIZATION: Read bytes ONCE.
          Uint8List? originBytes = await asset.originBytes;
          if (originBytes == null) return null; // Skip invalid assets

          try {
            // Process using the loaded bytes (Heavy CPU)
            Uint8List? processedBytes = await _imageProcessor.processImage(
              originBytes,
              settings,
              isExportProcessing: true,
            );

            // Preserve Metadata using the same loaded bytes (No extra I/O)
            if (preserveMetadata) {
               processedBytes = _preserveMetadata(originBytes, processedBytes);
            }

            // Save Logic
            final originalName = asset.title ?? 'photo_${globalIndex + 1}';
            final baseName = originalName.replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '');
            final exportFileName = '${baseName}_instaframe.jpg';
            final tempFile = File('${exportDir.path}/$exportFileName');
            
            await tempFile.writeAsBytes(processedBytes);
            await Gal.putImage(tempFile.path);
            await tempFile.delete();

            // GC Hint: clear reference to huge arrays immediately
            processedBytes = null; 
            
            return globalIndex + 1;
          } finally {
            // GC Hint: clear input bytes immediately
            originBytes = null;
          }
        });

        final results = await Future.wait(batchFutures);

        for (final result in results) {
          if (result != null) {
            yield result;
            completedCount++;
          }
        }
      }
    } finally {
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
    }
  }

  /// Synchronous implementation if bytes are already loaded. 
  /// The logic is fast enough to run on the compute thread or main thread 
  /// without being async since it's just array manipulation.
  Uint8List _preserveMetadata(Uint8List originalBytes, Uint8List processedBytes) {
    try {
      if (originalBytes.length < 4) return processedBytes;

      final exifSegment = _extractExifSegment(originalBytes);
      if (exifSegment == null) return processedBytes;

      return _insertExifSegment(processedBytes, exifSegment);
    } catch (e) {
      log('Failed to preserve metadata: $e');
      return processedBytes;
    }
  }

  Uint8List? _extractExifSegment(Uint8List jpegBytes) {
    if (jpegBytes.length < 4) return null;
    if (jpegBytes[0] != 0xFF || jpegBytes[1] != 0xD8) return null;

    int offset = 2;
    while (offset < jpegBytes.length - 4) {
      //look for EXIF APP1 marker (0xFFE1)
      if (jpegBytes[offset] == 0xFF && jpegBytes[offset + 1] == 0xE1) {
        
        final length = (jpegBytes[offset + 2] << 8) | jpegBytes[offset + 3];
        // Check for "Exif" header
        if (offset + 8 < jpegBytes.length &&
            jpegBytes[offset + 4] == 0x45 &&  // 'E'
            jpegBytes[offset + 5] == 0x78 &&  // 'x'
            jpegBytes[offset + 6] == 0x69 &&  // 'i'
            jpegBytes[offset + 7] == 0x66) { // 'f'
            //found exif segment
          return jpegBytes.sublist(offset, offset + 2 + length);
        }
      }
      
      // Navigate next marker
      if (jpegBytes[offset] == 0xFF) {
         // If it's SOS (Start of Scan), Stop. Exif is always before SOS.
         if (jpegBytes[offset + 1] == 0xDA) break;
         
         if (jpegBytes[offset + 1] != 0x00) {
            final length = (jpegBytes[offset + 2] << 8) | jpegBytes[offset + 3];
            offset += 2 + length;
         } else {
            offset++;
         }
      } else {
        offset++;
      }
    }
    return null;
  }

  Uint8List _insertExifSegment(Uint8List jpegBytes, Uint8List exifSegment) {
    if (jpegBytes.length < 4) return jpegBytes;
    
    final result = BytesBuilder();
    result.addByte(0xFF);
    result.addByte(0xD8);
    result.add(exifSegment);
    result.add(jpegBytes.sublist(2));
    
    return result.toBytes();
  }
}