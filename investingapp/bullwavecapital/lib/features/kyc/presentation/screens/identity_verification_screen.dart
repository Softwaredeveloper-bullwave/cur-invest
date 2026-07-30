import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../domain/kyc_models.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_step_scaffold.dart';
import '../widgets/kyc_widgets.dart';
import '../widgets/selfie_manual_review_panel.dart';

/// Combined manual UPI + selfie step — both sent to admin for approval.
class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  State<IdentityVerificationScreen> createState() => _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vpaController = TextEditingController();
  final _mobileController = TextEditingController();
  CameraController? _controller;
  Uint8List? _capturedBytes;
  bool _cameraReady = false;
  String? _cameraError;
  bool _submitting = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _vpaController.addListener(() {
      _syncMobileFromVpa(_vpaController.text);
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<KycFlowProvider>().loadKycStatus();
      if (!mounted) return;
      final phone = context.read<AuthProvider>().user?.phone ?? '';
      if (phone.length == 10 && _mobileController.text.isEmpty) {
        _mobileController.text = phone;
      }
      _maybeInitCamera();
      _startPolling();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    unawaited(_releaseCamera());
    _vpaController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _releaseCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        await controller.dispose();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _cameraReady = false;
        _cameraError = null;
      });
    }
  }

  void _syncMobileFromVpa(String vpa) {
    final trimmed = vpa.trim().toLowerCase();
    if (!trimmed.contains('@')) return;
    final local = trimmed.split('@').first.replaceAll(RegExp(r'\D'), '');
    if (local.length == 10 && RegExp(r'^[6-9]').hasMatch(local)) {
      _mobileController.text = local;
    }
  }

  bool _needsLinkedMobile(String vpa) {
    final trimmed = vpa.trim().toLowerCase();
    if (!trimmed.contains('@')) return true;
    final local = trimmed.split('@').first.replaceAll(RegExp(r'\D'), '');
    return !(local.length == 10 && RegExp(r'^[6-9]').hasMatch(local));
  }

  bool _upiSubmittedForReview(KycStatusModel s) =>
      s.upiManual &&
      s.upiStatus == 'pending' &&
      s.upiVpaMasked.isNotEmpty;

  bool _stillNeedsUpi(KycStatusModel s) => !s.upiVerified && !_upiSubmittedForReview(s);

  bool _stillNeedsSelfie(KycStatusModel s) =>
      !s.selfieVerified && !s.selfieReviewPending;

  bool _awaitingAdminReview(KycStatusModel s) =>
      s.selfieReviewPending ||
      _upiSubmittedForReview(s) ||
      (s.upiVerified &&
          s.selfieVerified &&
          s.manualFinalApprovalRequired &&
          !s.finalKycApproved);

  void _startPolling() {
    _pollTimer?.cancel();
    final kyc = context.read<KycFlowProvider>();
    if (!_awaitingAdminReview(kyc.status)) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
      await context.read<KycFlowProvider>().loadKycStatus();
      if (!mounted) return;
      final s = context.read<KycFlowProvider>().status;
      if (_awaitingAdminReview(s)) {
        await _releaseCamera();
      }
      if (s.finalKycApproved || s.isFullyVerified) {
        _pollTimer?.cancel();
        OnboardingFlowNavigator.goToNextKycStep(context, context.read<KycFlowProvider>());
      }
      setState(() {});
    });
  }

  Future<void> _maybeInitCamera() async {
    final s = context.read<KycFlowProvider>().status;
    if (!_stillNeedsSelfie(s) || _awaitingAdminReview(s)) return;

    if (!kIsWeb) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted || !mounted) {
        setState(() => _cameraError = 'Camera permission is required.');
        return;
      }
    }

    setState(() {
      _cameraReady = false;
      _cameraError = null;
    });

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _cameraError = 'No camera found on this device.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      await _controller?.dispose();
      final controller = kIsWeb
          ? CameraController(front, ResolutionPreset.medium, enableAudio: false)
          : CameraController(
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
        _cameraReady = true;
        _cameraError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = kIsWeb
            ? 'Could not open camera. Allow camera access in your browser and reload.'
            : 'Could not open front camera. Please try again.';
        _cameraReady = false;
      });
    }
  }

  Uint8List _compressSelfie(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  Future<void> _captureSelfie() async {
    if (!_cameraReady || _controller == null) {
      await _maybeInitCamera();
      if (!_cameraReady || _controller == null) return;
    }
    final controller = _controller!;
    if (!controller.value.isInitialized) return;
    final file = await controller.takePicture();
    final bytes = _compressSelfie(await file.readAsBytes());
    if (!mounted) return;
    setState(() => _capturedBytes = bytes);
  }

  Future<void> _submitAll() async {
    final kyc = context.read<KycFlowProvider>();
    final s = kyc.status;
    final needsUpi = _stillNeedsUpi(s);
    final needsSelfie = _stillNeedsSelfie(s);

    if (needsUpi && !_formKey.currentState!.validate()) return;
    if (needsSelfie && _capturedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a live selfie before submitting.')),
      );
      return;
    }

    setState(() => _submitting = true);

    if (needsUpi) {
      final vpa = _vpaController.text.trim();
      if (_needsLinkedMobile(vpa) && _mobileController.text.trim().length != 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the 10-digit mobile linked to this UPI ID.')),
        );
        setState(() => _submitting = false);
        return;
      }
      final upiOk = await kyc.verifyUpi(
        upiVpa: vpa,
        recipientMobile: _mobileController.text.trim(),
      );
      if (!mounted) return;
      if (!upiOk && kyc.error != null) {
        setState(() => _submitting = false);
        return;
      }
    }

    if (needsSelfie && _capturedBytes != null) {
      final selfieOk = await kyc.uploadSelfie(_capturedBytes!);
      if (!mounted) return;
      if (selfieOk) {
        await _releaseCamera();
        _capturedBytes = null;
      }
      setState(() => _submitting = false);
      if (!selfieOk && kyc.error != null) return;
    } else {
      setState(() => _submitting = false);
    }

    if (!mounted) return;
    await kyc.loadKycStatus();
    if (!mounted) return;
    if (_awaitingAdminReview(kyc.status)) {
      await _releaseCamera();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Submitted for admin verification. Our team will review your UPI and selfie within 24 hours.',
        ),
      ),
    );
    _startPolling();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KycFlowProvider>(
      builder: (context, kyc, _) {
        final s = kyc.status;
        final needsUpi = _stillNeedsUpi(s);
        final needsSelfie = _stillNeedsSelfie(s);
        final awaitingReview = _awaitingAdminReview(s) && !needsUpi && !needsSelfie;

        return KycStepScaffold(
          title: 'UPI & selfie verification',
          subtitle:
              'Enter your UPI ID and capture a live selfie. Both are sent to our compliance team for manual approval.',
          stepLabel: 'FINAL IDENTITY CHECK',
          stepIndex: 5,
          totalSteps: 5,
          icon: Icons.face_retouching_natural_outlined,
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (kyc.error != null) ...[
                KycErrorBanner(message: kyc.error!),
                const SizedBox(height: 12),
              ],
              if (awaitingReview) ...[
                if (s.selfieReviewPending) SelfieManualReviewPendingPanel(status: s),
                if (_upiSubmittedForReview(s) && !s.selfieReviewPending)
                  const KycInfoCard(
                    tone: KycInfoTone.warning,
                    title: 'UPI under review',
                    message:
                        'Your UPI ID has been submitted. Our team will verify it along with your selfie.',
                  ),
                if (s.upiVerified &&
                    s.selfieVerified &&
                    s.manualFinalApprovalRequired &&
                    !s.finalKycApproved)
                  const KycInfoCard(
                    tone: KycInfoTone.warning,
                    title: 'Final review in progress',
                    message:
                        'UPI and selfie are verified. An admin will complete your account verification shortly.',
                  ),
              ] else ...[
                if (needsUpi) ...[
                  Text(
                    'UPI ID',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          controller: _vpaController,
                          label: 'UPI ID (VPA)',
                          hint: 'yourname@upi',
                          keyboardType: TextInputType.emailAddress,
                          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Enter your UPI ID';
                            if (!value.contains('@')) return 'Enter a valid UPI ID';
                            return null;
                          },
                        ),
                        if (_needsLinkedMobile(_vpaController.text)) ...[
                          const SizedBox(height: 12),
                          AppTextField(
                            controller: _mobileController,
                            label: 'Linked mobile (optional override)',
                            hint: '10-digit mobile',
                            keyboardType: TextInputType.phone,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (_upiSubmittedForReview(s) || s.upiVerified)
                  KycInfoCard(
                    tone: KycInfoTone.success,
                    title: 'UPI submitted',
                    message: s.upiVpaMasked.isNotEmpty
                        ? '${s.upiVpaMasked} — pending admin verification'
                        : 'Your UPI ID is on file.',
                  ),
                if (needsSelfie) ...[
                  Text(
                    'Live selfie',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: ColoredBox(
                        color: Colors.black,
                        child: _capturedBytes != null
                            ? Image.memory(_capturedBytes!, fit: BoxFit.cover)
                            : _cameraReady && _controller != null
                                ? CameraPreview(_controller!)
                                : Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_cameraError == null)
                                            const CircularProgressIndicator(color: AppColors.brandOrange)
                                          else ...[
                                            const Icon(Icons.videocam_off_outlined,
                                                color: AppColors.brandOrange, size: 40),
                                            const SizedBox(height: 12),
                                            Text(
                                              _cameraError!,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.85),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            OutlinedButton(
                                              onPressed: _maybeInitCamera,
                                              child: const Text('Retry camera'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _capturedBytes == null
                              ? _captureSelfie
                              : () {
                                  setState(() => _capturedBytes = null);
                                  _maybeInitCamera();
                                },
                          child: Text(_capturedBytes == null ? 'Capture selfie' : 'Retake'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ] else if (s.selfieVerified)
                  const KycInfoCard(
                    tone: KycInfoTone.success,
                    title: 'Selfie verified',
                    message: 'Your selfie has been approved.',
                  ),
                if (needsUpi || needsSelfie)
                  PrimaryButton(
                    label: _submitting ? 'Submitting…' : 'Submit for verification',
                    onPressed: _submitting ? null : _submitAll,
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
