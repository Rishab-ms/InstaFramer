import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import '../blocs/photo_bloc/photo_bloc.dart';
import '../blocs/photo_bloc/photo_event.dart';

/// Photo picker service for InstaFramer.
/// 
/// Provides a static interface to launch the gallery picker using
/// [wechat_assets_picker] with proper permission handling.
/// 
/// Features:
/// - Multi-select up to 30 photos
/// - Android permission request and handling
/// - Themed picker matching app theme
/// - Error handling with user-friendly dialogs
class PhotoPickerScreen {
  /// Launch the photo picker and handle photo selection.
  /// 
  /// Workflow:
  /// 1. Request Android photo permissions
  /// 2. Show permission dialog if denied
  /// 3. Launch wechat_assets_picker with custom theme
  /// 4. Dispatch [PhotosSelected] event to [PhotoBloc] with results
  /// 
  /// [context] - BuildContext to access BLoC and show dialogs
  static Future<void> pickPhotos(BuildContext context) async {
    try {
      // Request photo access permission from Android
      // Handles both Android 13+ granular permissions and legacy storage permissions
      final PermissionState permissionState = await PhotoManager.requestPermissionExtend();
      
      if (permissionState != PermissionState.authorized && 
          permissionState != PermissionState.limited) {
        // Permission denied - show dialog to guide user to settings
        if (context.mounted) {
          _showPermissionDeniedDialog(context);
        }
        return;
      }

      // Launch the picker with custom configuration
      final List<AssetEntity>? result = await AssetPicker.pickAssets(
        context,
        pickerConfig: AssetPickerConfig(
          maxAssets: 30, // Instagram batch limit
          requestType: RequestType.image, // Images only, no videos
          selectedAssets: const [],
          textDelegate: const EnglishAssetPickerTextDelegate(),
          themeColor: Theme.of(context).colorScheme.primary,
          pickerTheme: _buildPickerTheme(context),
          specialItemPosition: SpecialItemPosition.prepend,
          specialItemBuilder: (context, path, length) {
            return _buildCameraButton(context);
          },
          sortPathsByModifiedDate: true, // Show recent photos first
        ),
      );

      // Handle selection result
      if (result != null && result.isNotEmpty && context.mounted) {
        // Dispatch selected photos to PhotoBloc
        context.read<PhotoBloc>().add(PhotosSelectedEvent(result));
      } else if (context.mounted) {
        // User cancelled - clear any previous state
        context.read<PhotoBloc>().add(const ClearPhotosEvent());
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'Failed to access photos: ${e.message}');
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'An unexpected error occurred: $e');
      }
    }
  }

  /// Build a custom theme for the picker to match app theme.
  /// 
  /// Creates a ThemeData that matches the current app theme (light/dark)
  /// to provide a seamless user experience.
  static ThemeData _buildPickerTheme(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();
    
    return baseTheme.copyWith(
      primaryColor: Theme.of(context).colorScheme.primary,
      colorScheme: Theme.of(context).colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      scaffoldBackgroundColor: Theme.of(context).colorScheme.background,
    );
  }

  /// Build camera button widget for special item position.
  /// 
  /// Note: This is a placeholder - actual camera functionality not implemented in V1.
  static Widget _buildCameraButton(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              'Camera',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show permission denied dialog with option to open system settings.
  /// 
  /// Guides the user to grant photo access permissions through Android settings.
  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: const Text(
          'InstaFramer needs access to your photos to frame them. '
          'Please grant photo access permission in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              PhotoManager.openSetting();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog for unexpected errors.
  /// 
  /// Displays platform-specific errors or general exceptions to the user.
  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

