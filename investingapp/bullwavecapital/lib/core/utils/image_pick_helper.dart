import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gallery / camera picking with platform permissions and safe error handling.
class ImagePickHelper {
  ImagePickHelper._();

  static final _picker = ImagePicker();

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Desktop gallery uses [file_selector] — no photos permission needed.
  static bool get _galleryUsesFileSelector => isDesktop;

  static Future<bool> ensurePermission(ImageSource source) async {
    if (kIsWeb) return true;

    if (source == ImageSource.camera) {
      if (isDesktop) return true;
      final status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
    }

    if (_galleryUsesFileSelector) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final photos = await Permission.photos.request();
        if (photos.isGranted || photos.isLimited) return true;
        final storage = await Permission.storage.request();
        return storage.isGranted;
      case TargetPlatform.iOS:
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
    BuildContext? context,
  }) async {
    if (requestPermission) {
      final allowed = await ensurePermission(source);
      if (!allowed) return null;
    }

    if (source == ImageSource.camera && isDesktop) {
      if (context == null) return null;
      return _captureDesktopPhoto(context, maxWidth: maxWidth, imageQuality: imageQuality);
    }

    return _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
      preferredCameraDevice: CameraDevice.front,
    );
  }

  static Future<XFile?> _captureDesktopPhoto(
    BuildContext context, {
    required double maxWidth,
    required int imageQuality,
  }) async {
    final bytes = await showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DesktopCameraDialog(),
    );
    if (bytes == null || bytes.isEmpty) return null;

    final compressed = _compress(bytes, maxWidth: maxWidth, quality: imageQuality);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/capture_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(path);
    await file.writeAsBytes(compressed);
    return XFile(path);
  }

  static Uint8List _compress(Uint8List bytes, {required double maxWidth, required int quality}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > maxWidth ? img.copyResize(decoded, width: maxWidth.round()) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality.clamp(1, 100)));
  }

  static String permissionDeniedMessage(ImageSource source) {
    return source == ImageSource.camera
        ? 'Camera permission is required. Enable it in Settings and try again.'
        : 'Photo library access is required. Enable it in Settings and try again.';
  }

  static String pickFailedMessage(ImageSource source) {
    if (source == ImageSource.camera && isDesktop) {
      return 'Could not open the camera. Check System Settings → Privacy → Camera for BullWave.';
    }
    return source == ImageSource.camera
        ? 'Could not open the camera. Check permission and try again.'
        : 'Could not open the gallery. Check permission and try again.';
  }
}

class _DesktopCameraDialog extends StatefulWidget {
  const _DesktopCameraDialog();

  @override
  State<_DesktopCameraDialog> createState() => _DesktopCameraDialogState();
}

class _DesktopCameraDialogState extends State<_DesktopCameraDialog> {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _openCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 10));
      if (cameras.isEmpty) throw StateError('No camera found');

      final ordered = <CameraDescription>[
        ...cameras.where((c) => c.lensDirection == CameraLensDirection.front),
        ...cameras.where((c) => c.lensDirection != CameraLensDirection.front),
      ];

      for (final camera in ordered) {
        try {
          final controller = CameraController(
            camera,
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.jpeg,
          );
          await controller.initialize();
          if (!mounted) {
            await controller.dispose();
            return;
          }
          setState(() {
            _controller?.dispose();
            _controller = controller;
            _initializing = false;
            _error = null;
          });
          return;
        } catch (_) {}
      }
      throw StateError('Could not start camera');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      Navigator.pop(context, bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Capture failed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Take a photo'),
      content: SizedBox(
        width: 360,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: Colors.black,
              child: _initializing
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      : _controller != null && _controller!.value.isInitialized
                          ? CameraPreview(_controller!)
                          : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        if (_controller != null && _error == null)
          FilledButton(onPressed: _capture, child: const Text('Capture')),
      ],
    );
  }
}
