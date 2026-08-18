import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/colors.dart';

/// Gallery / camera picking with platform permissions and safe error handling.
class ImagePickHelper {
  ImagePickHelper._();

  static final _picker = ImagePicker();
  static bool? _cachedIosWithoutCamera;

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  /// Best-effort iOS Simulator check (Platform.environment is often empty on iOS).
  static bool get isIosSimulator {
    if (kIsWeb || !Platform.isIOS) return false;
    const keys = [
      'SIMULATOR_DEVICE_NAME',
      'SIMULATOR_ROOT',
      'SIMULATOR_UDID',
      'IPHONE_SIMULATOR',
    ];
    for (final key in keys) {
      if (Platform.environment.containsKey(key)) return true;
    }
    return _cachedIosWithoutCamera == true;
  }

  /// iOS Simulator / devices with no camera hardware exposed to the app.
  static Future<bool> isIosWithoutCamera() async {
    if (kIsWeb || !Platform.isIOS) return false;
    if (_cachedIosWithoutCamera != null) return _cachedIosWithoutCamera!;
    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 4));
      _cachedIosWithoutCamera = cameras.isEmpty;
    } catch (_) {
      _cachedIosWithoutCamera = true;
    }
    return _cachedIosWithoutCamera!;
  }

  static Future<bool> hasUsableCamera() async {
    if (isDesktop) return true;
    if (Platform.isIOS && await isIosWithoutCamera()) return false;
    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 5));
      return cameras.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Selfie bytes for KYC — live camera on device; gallery on iOS Simulator.
  static Future<Uint8List?> captureSelfie({
    required BuildContext context,
    double maxWidth = 1280,
    int imageQuality = 85,
  }) async {
    if (isDesktop) {
      final file = await pickImage(
        source: ImageSource.camera,
        context: context,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
        requestPermission: false,
      );
      if (file == null) return null;
      return _compress(await file.readAsBytes(), maxWidth: maxWidth, quality: imageQuality);
    }

    if (Platform.isIOS && await isIosWithoutCamera()) {
      return _pickFromGallery(
        context,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
        simulatorMode: true,
      );
    }

    final hasCamera = await hasUsableCamera();
    if (!hasCamera) {
      return _pickFromGallery(
        context,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
        simulatorMode: false,
      );
    }

    try {
      final file = await pickImage(
        source: ImageSource.camera,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
      if (file != null) {
        return _compress(await file.readAsBytes(), maxWidth: maxWidth, quality: imageQuality);
      }
    } catch (_) {}

    return _pickFromGallery(
      context,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
      simulatorMode: Platform.isIOS,
    );
  }

  /// Opens the photo library directly (simulator / no-camera fallback).
  static Future<Uint8List?> _pickFromGallery(
    BuildContext context, {
    required double maxWidth,
    required int imageQuality,
    required bool simulatorMode,
  }) async {
    if (simulatorMode && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Simulator has no camera — pick a selfie photo from your Mac library.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    final file = await pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
      requestPermission: true,
    );
    if (file == null) return null;
    return _compress(await file.readAsBytes(), maxWidth: maxWidth, quality: imageQuality);
  }


  /// Desktop gallery uses [file_selector] — no photos permission needed.
  static bool get _galleryUsesFileSelector => isDesktop;

  /// Android gallery uses the system photo picker — no READ_MEDIA_* permission.
  static bool get _androidGalleryUsesSystemPicker =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> ensurePermission(ImageSource source) async {
    if (kIsWeb) return true;

    if (source == ImageSource.camera) {
      if (isDesktop) return true;
      final status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
    }

    if (_galleryUsesFileSelector || _androidGalleryUsesSystemPicker) return true;

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        final photos = await Permission.photos.request();
        return photos.isGranted || photos.isLimited;
      default:
        return true;
    }
  }

  static Future<Uint8List> _readImageBytes(XFile file) async {
    try {
      return await file.readAsBytes();
    } catch (_) {
      final path = file.path;
      if (!kIsWeb && path.isNotEmpty) {
        return File(path).readAsBytes();
      }
      rethrow;
    }
  }

  /// Profile avatar — pick, compress, and return JPEG bytes for upload.
  static Future<({Uint8List bytes, String filename})?> pickProfileAvatar({
    required BuildContext context,
    required ImageSource source,
  }) async {
    if (source == ImageSource.camera) {
      final allowed = await ensurePermission(ImageSource.camera);
      if (!allowed) return null;
    }

    final file = await pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestPermission: false,
      context: context,
    );
    if (file == null) return null;

    final raw = await _readImageBytes(file);
    if (raw.isEmpty) {
      throw const FormatException('Photo file is empty.');
    }
    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw const FormatException('Could not process photo. Try another JPEG or PNG image.');
    }
    final resized = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;
    final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
    if (bytes.isEmpty) {
      throw const FormatException('Could not prepare photo for upload.');
    }
    return (bytes: bytes, filename: 'avatar.jpg');
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
      preferredCameraDevice:
          source == ImageSource.camera ? CameraDevice.front : CameraDevice.rear,
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
    if (source == ImageSource.camera) {
      return 'Camera permission is required. Enable it in Settings and try again.';
    }
    if (_androidGalleryUsesSystemPicker) {
      return 'Could not open the photo picker. Try again.';
    }
    return 'Photo library access is required. Enable it in Settings and try again.';
  }

  static String pickFailedMessage(ImageSource source) {
    if (source == ImageSource.camera && isDesktop) {
      return 'Could not open the camera. Check System Settings → Privacy → Camera for BullWave.';
    }
    if (source == ImageSource.camera) {
      return 'Could not open the camera. Check permission and try again.';
    }
    if (_androidGalleryUsesSystemPicker) {
      return 'Could not open the photo picker. Try again.';
    }
    return 'Could not open the gallery. Check permission and try again.';
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
