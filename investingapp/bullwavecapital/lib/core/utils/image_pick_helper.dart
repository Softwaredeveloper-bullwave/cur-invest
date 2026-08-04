import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gallery / camera picking with platform permissions and safe error handling.
class ImagePickHelper {
  ImagePickHelper._();

  static final _picker = ImagePicker();

  static Future<bool> ensurePermission(ImageSource source) async {
    if (kIsWeb) return true;

    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final photos = await Permission.photos.request();
        if (photos.isGranted || photos.isLimited) return true;
        final storage = await Permission.storage.request();
        return storage.isGranted;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      default:
        return true;
    }
  }

  static Future<XFile?> pickImage({
    required ImageSource source,
    double maxWidth = 1024,
    double maxHeight = 1024,
    int imageQuality = 85,
    bool requestPermission = true,
  }) async {
    if (requestPermission) {
      final allowed = await ensurePermission(source);
      if (!allowed) return null;
    }

    return _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: CameraDevice.front,
    );
  }

  static String permissionDeniedMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Camera permission is required. Enable it in Settings and try again.'
        : 'Photo library access is required. Enable it in Settings and try again.';
  }

  static String pickFailedMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Could not open the camera. Check permission and try again.'
        : 'Could not open the gallery. Check permission and try again.';
  }
}
