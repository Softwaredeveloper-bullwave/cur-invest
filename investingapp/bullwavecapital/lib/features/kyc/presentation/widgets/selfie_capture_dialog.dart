import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/primary_button.dart';

/// Full-screen live selfie capture — more reliable on macOS/desktop than inline preview.
class SelfieCaptureDialog extends StatefulWidget {
  const SelfieCaptureDialog({super.key});

  static Future<Uint8List?> show(BuildContext context) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SelfieCaptureDialog(),
    );
  }

  @override
  State<SelfieCaptureDialog> createState() => _SelfieCaptureDialogState();
}

class _SelfieCaptureDialogState extends State<SelfieCaptureDialog> {
  CameraController? _controller;
  bool _initializing = true;
  String? _error;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    unawaited(_openCamera());
  }

  @override
  void dispose() {
    unawaited(_disposeController());
    super.dispose();
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
  }

  Future<void> _openCamera() async {
    setState(() {
      _initializing = true;
      _error = null;
    });

    await _disposeController();

    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 10));
      if (cameras.isEmpty) {
        throw StateError('No camera found on this device.');
      }

      final ordered = <CameraDescription>[
        ...cameras.where((c) => c.lensDirection == CameraLensDirection.front),
        ...cameras.where((c) => c.lensDirection != CameraLensDirection.front),
      ];

      Object? lastError;
      for (final camera in ordered) {
        CameraController? trial;
        try {
          final useJpeg = defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS;
          final preset = _isDesktop ? ResolutionPreset.medium : ResolutionPreset.high;
          trial = useJpeg
              ? CameraController(
                  camera,
                  preset,
                  enableAudio: false,
                  imageFormatGroup: ImageFormatGroup.jpeg,
                )
              : CameraController(camera, preset, enableAudio: false);

          await trial.initialize().timeout(const Duration(seconds: 10));
          if (!mounted) {
            await trial.dispose();
            return;
          }
          setState(() {
            _controller = trial;
            _initializing = false;
            _error = null;
          });
          return;
        } catch (e) {
          lastError = e;
          await trial?.dispose();
        }
      }

      throw lastError ?? StateError('Could not open camera');
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'Camera took too long to start. Check macOS Settings → Privacy → Camera.';
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not open camera. Allow camera access in System Settings and retry.';
        _initializing = false;
      });
    }
  }

  Uint8List _compress(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      final bytes = _compress(await file.readAsBytes());
      if (!mounted) return;
      await _disposeController();
      Navigator.of(context).pop(bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _initializing
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.brandOrange),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _openCamera,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : controller != null && controller.value.isInitialized
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: AspectRatio(
                                  aspectRatio: 3 / 4,
                                  child: CameraPreview(controller),
                                ),
                              )
                            : const SizedBox.shrink(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: PrimaryButton(
                label: 'Capture selfie',
                onPressed: (_initializing || _error != null) ? null : _capture,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
