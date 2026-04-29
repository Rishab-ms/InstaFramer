import 'package:photo_manager/photo_manager.dart';

/// Shared helper for requesting photo-library permission.
///
/// We treat both `authorized` and `limited` as "allowed" since the app can
/// operate with limited access (and the picker already supports it).
class PhotoPermissionService {
  static Future<bool> requestPhotosPermission() async {
    final permission = await PhotoManager.requestPermissionExtend();
    return permission == PermissionState.authorized ||
        permission == PermissionState.limited;
  }
}
