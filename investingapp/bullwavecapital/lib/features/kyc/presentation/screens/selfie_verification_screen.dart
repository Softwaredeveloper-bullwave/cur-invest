import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';
import '../widgets/selfie_manual_review_panel.dart';

enum _SelfiePhase { loading, camera, preview, uploading, pending, verified, rejected }

class SelfieVerificationScreen extends StatefulWidget {
  const SelfieVerificationScreen({super.key});

  @override
  State<SelfieVerificationScreen> createState() => _SelfieVerificationScreenState();
}

class _SelfieVerificationScreenState extends State<SelfieVerificationScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  _SelfiePhase _phase = _SelfiePhase.loading;
  Uint8List? _capturedBytes;
  String? _cameraError;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<KycFlowProvider>().loadKycStatus();
      if (!mounted) return;
      _syncPhaseFromStatus();
      if (_phase == _SelfiePhase.loading && !_shouldShowPendingOrVerified()) {
        await _initCamera();
      }
      _startPollingIfNeeded();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed && _phase == _SelfiePhase.camera) {
      _initCamera();
    }
  }

  bool _shouldShowPendingOrVerified() {
    final s = context.read<KycFlowProvider>().status;
    return s.selfieReviewPending || s.selfieVerified || s.selfieReviewRejected;
  }

  void _syncPhaseFromStatus() {
    final s = context.read<KycFlowProvider>().status;
    if (s.selfieVerified) {
      setState(() => _phase = _SelfiePhase.verified);
    } else if (s.selfieReviewPending) {
      setState(() => _phase = _SelfiePhase.pending);
    } else if (s.selfieReviewRejected) {
      setState(() => _phase = _SelfiePhase.rejected);
    }
  }

  void _startPollingIfNeeded() {
    _pollTimer?.cancel();
    final kyc = context.read<KycFlowProvider>();
    if (!kyc.status.selfieReviewPending) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      await kyc.loadKycStatus();
      if (!mounted) return;
      final s = kyc.status;
      if (s.selfieVerified) {
        _pollTimer?.cancel();
        setState(() => _phase = _SelfiePhase.verified);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selfie verified! Continuing KYC…')),
        );
        OnboardingFlowNavigator.goToNextKycStep(context, kyc);
      } else if (s.selfieReviewRejected) {
        _pollTimer?.cancel();
        setState(() => _phase = _SelfiePhase.rejected);
      }
    });
  }

  Future<void> _initCamera() async {
    setState(() {
      _phase = _SelfiePhase.loading;
      _cameraError = null;
    });

    final permission = await Permission.camera.request();
    if (!permission.isGranted) {
      setState(() {
        _cameraError = 'Camera permission is required to capture your selfie.';
        _phase = _SelfiePhase.camera;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );

      await _controller?.dispose();
      final controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _phase = _SelfiePhase.camera;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Could not open front camera. Please try again.';
        _phase = _SelfiePhase.camera;
      });
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      final raw = await file.readAsBytes();
      final compressed = _compressSelfie(raw);
      setState(() {
        _capturedBytes = compressed;
        _phase = _SelfiePhase.preview;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo. Please try again.')),
      );
    }
  }

  Uint8List _compressSelfie(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > 1280
        ? img.copyResize(decoded, width: 1280)
        : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  void _retake() {
    setState(() {
      _capturedBytes = null;
      _phase = _SelfiePhase.camera;
    });
    if (_controller == null || !_controller!.value.isInitialized) {
      _initCamera();
    }
  }

  Future<void> _confirmUpload() async {
    final bytes = _capturedBytes;
    if (bytes == null) return;

    setState(() => _phase = _SelfiePhase.uploading);
    final kyc = context.read<KycFlowProvider>();
    final ok = await kyc.uploadSelfie(bytes);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selfie uploaded successfully.')),
      );
      setState(() => _phase = _SelfiePhase.pending);
      _startPollingIfNeeded();
      return;
    }

    setState(() => _phase = _SelfiePhase.preview);
  }

  Future<void> _continueAfterVerified() async {
    final kyc = context.read<KycFlowProvider>();
    OnboardingFlowNavigator.goToNextKycStep(context, kyc);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final kyc = context.watch<KycFlowProvider>();
    final status = kyc.status;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(title: 'Selfie Verification'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Live selfie capture',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Position your face in the frame. Only the front camera is used — gallery uploads are not allowed.',
            style: TextStyle(color: colors.textSecondary, height: 1.45),
          ),
          const SizedBox(height: 20),
          if (status.selfieReviewRejected && _phase != _SelfiePhase.camera)
            SelfieManualReviewRejectedPanel(
              message: status.selfieReviewMessage,
              onRetake: () async {
                setState(() => _phase = _SelfiePhase.loading);
                await _initCamera();
              },
            )
          else if (_phase == _SelfiePhase.pending || status.selfieReviewPending)
            SelfieManualReviewPendingPanel(status: status)
          else if (_phase == _SelfiePhase.verified || status.selfieVerified) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.green),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Selfie verified by our team.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: OnboardingFlowNavigator.labelForNextKycStep(kyc),
              onPressed: kyc.isLoading ? null : _continueAfterVerified,
            ),
          ] else ...[
            _buildCameraSection(colors),
            if (kyc.error != null) ...[
              const SizedBox(height: 16),
              KycErrorBanner(message: kyc.error!),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCameraSection(AppThemeExtension colors) {
    if (_cameraError != null) {
      return Column(
        children: [
          KycErrorBanner(message: _cameraError!),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Retry camera', onPressed: _initCamera),
        ],
      );
    }

    if (_phase == _SelfiePhase.loading || _phase == _SelfiePhase.uploading) {
      return SizedBox(
        height: 420,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.brandOrange),
              const SizedBox(height: 16),
              Text(
                _phase == _SelfiePhase.uploading
                    ? 'Uploading selfie…'
                    : 'Starting front camera…',
                style: TextStyle(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (_phase == _SelfiePhase.preview && _capturedBytes != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.memory(_capturedBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: context.read<KycFlowProvider>().isLoading ? null : _retake,
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Confirm',
                  onPressed: context.read<KycFlowProvider>().isLoading ? null : _confirmUpload,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox(
        height: 420,
        child: Center(child: CircularProgressIndicator(color: AppColors.brandOrange)),
      );
    }

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                CustomPaint(painter: _FaceGuidePainter()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Keep your face inside the oval and look at the camera.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Capture selfie',
          onPressed: _capture,
        ),
      ],
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.35);
    canvas.drawRect(Offset.zero & size, overlay);

    final center = Offset(size.width / 2, size.height * 0.42);
    final oval = Rect.fromCenter(
      center: center,
      width: size.width * 0.62,
      height: size.height * 0.48,
    );
    canvas.drawOval(oval, Paint()..blendMode = BlendMode.clear);

    final border = Paint()
      ..color = AppColors.brandOrange.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(oval, border);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
