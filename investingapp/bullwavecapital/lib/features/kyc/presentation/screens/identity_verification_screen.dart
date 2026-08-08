import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../widgets/selfie_capture_dialog.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/navigation/registration_completion.dart';
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

class _IdentityVerificationScreenState extends State<IdentityVerificationScreen>
    with WidgetsBindingObserver {
  static const _selfiePreviewMaxHeight = 320.0;

  final _formKey = GlobalKey<FormState>();
  final _vpaController = TextEditingController();
  final _mobileController = TextEditingController();
  CameraController? _controller;
  Uint8List? _capturedBytes;
  bool _cameraReady = false;
  bool _cameraInitializing = false;
  String? _cameraError;
  bool _submitting = false;
  Timer? _pollTimer;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      if (!_isDesktop) {
        _maybeInitCamera();
      }
      _startPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    unawaited(_releaseCamera());
    _vpaController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_capturedBytes != null) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      unawaited(_releaseCamera());
    } else if (state == AppLifecycleState.resumed) {
      _maybeInitCamera();
    }
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
        _cameraInitializing = false;
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
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      await context.read<KycFlowProvider>().loadKycStatus();
      if (!mounted) return;
      final s = context.read<KycFlowProvider>().status;
      if (_awaitingAdminReview(s)) {
        await _releaseCamera();
      }
      if (s.finalKycApproved || s.isFullyVerified) {
        _pollTimer?.cancel();
        if (context.read<AuthProvider>().isRegistrationFlow) {
          await RegistrationCompletion.finishAndGoHome(context);
          return;
        }
        if (!mounted) return;
        OnboardingFlowNavigator.goToNextKycStep(context, context.read<KycFlowProvider>());
      }
      setState(() {});
    });
  }

  Future<void> _maybeInitCamera({bool force = false}) async {
    final s = context.read<KycFlowProvider>().status;
    if (!_stillNeedsSelfie(s) || _awaitingAdminReview(s) || _capturedBytes != null) {
      return;
    }

    if (!force && (_cameraInitializing || _cameraReady)) return;

    setState(() {
      _cameraInitializing = true;
      _cameraReady = false;
      _cameraError = null;
    });

    if (!kIsWeb && !_isDesktop) {
      final permission = await Permission.camera.request();
      if (!permission.isGranted && !permission.isLimited) {
        if (!mounted) return;
        setState(() {
          _cameraError =
              'Camera permission is required. Enable it in Settings and try again.';
          _cameraInitializing = false;
        });
        return;
      }
    }

    try {
      final cameras = await availableCameras().timeout(const Duration(seconds: 12));
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraError =
              'No camera found. Live selfie is required — use a real phone (not Simulator).';
          _cameraInitializing = false;
        });
        return;
      }

      final ordered = <CameraDescription>[
        ...cameras.where((c) => c.lensDirection == CameraLensDirection.front),
        ...cameras.where((c) => c.lensDirection != CameraLensDirection.front),
      ];

      Object? lastError;
      for (final camera in ordered) {
        try {
          await _initCameraController(camera);
          return;
        } catch (e) {
          lastError = e;
        }
      }

      throw lastError ?? StateError('Could not open camera');
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _cameraError = 'Camera took too long to start. Tap below to retry.';
        _cameraReady = false;
        _cameraInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError = kIsWeb
            ? 'Could not open camera. Allow camera access in your browser and reload.'
            : 'Could not open the live camera. Tap below to retry.';
        _cameraReady = false;
        _cameraInitializing = false;
      });
    }
  }

  Future<void> _initCameraController(CameraDescription camera) async {
    await _releaseCamera();

    CameraController? trial;
    try {
      final useJpegFormat = defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
      final preset = _isDesktop ? ResolutionPreset.medium : ResolutionPreset.high;
      trial = useJpegFormat
          ? CameraController(
              camera,
              preset,
              enableAudio: false,
              imageFormatGroup: ImageFormatGroup.jpeg,
            )
          : CameraController(
              camera,
              preset,
              enableAudio: false,
            );
      await trial.initialize().timeout(const Duration(seconds: 10));
      if (!mounted) {
        await trial.dispose();
        return;
      }
      setState(() {
        _controller = trial;
        _cameraReady = true;
        _cameraError = null;
        _cameraInitializing = false;
      });
    } catch (e) {
      await trial?.dispose();
      rethrow;
    }
  }

  Future<void> _openSelfieCapture() async {
    if (_capturedBytes != null) return;

    if (_isDesktop) {
      final bytes = await SelfieCaptureDialog.show(context);
      if (!mounted || bytes == null) return;
      await _releaseCamera();
      setState(() {
        _capturedBytes = bytes;
        _cameraError = null;
      });
      return;
    }

    if (!_cameraReady || _controller == null) {
      await _startLiveCamera();
    }
    if (_cameraReady && _controller != null) {
      await _captureSelfie();
    }
  }

  Future<void> _startLiveCamera() async {
    if (_capturedBytes != null) return;
    await _maybeInitCamera(force: true);
  }

  Uint8List _compressSelfie(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    final resized = decoded.width > 1280 ? img.copyResize(decoded, width: 1280) : decoded;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 78));
  }

  Future<void> _captureSelfie() async {
    if (!_cameraReady || _controller == null) {
      await _startLiveCamera();
      if (!_cameraReady || _controller == null) return;
    }

    final controller = _controller!;
    if (!controller.value.isInitialized) return;
    try {
      final file = await controller.takePicture();
      final bytes = _compressSelfie(await file.readAsBytes());
      if (!mounted) return;
      setState(() => _capturedBytes = bytes);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not capture photo. Please try again.')),
      );
    }
  }

  Future<void> _retakeSelfie() async {
    setState(() => _capturedBytes = null);
    if (_isDesktop) {
      await _openSelfieCapture();
      return;
    }
    await _maybeInitCamera();
  }

  Future<void> _submitAll() async {
    final kyc = context.read<KycFlowProvider>();
    final s = kyc.status;
    final needsUpi = _stillNeedsUpi(s);
    final needsSelfie = _stillNeedsSelfie(s);

    if (!s.bankReadyForIdentity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complete live bank verification first. Saving bank details alone is not enough.',
          ),
        ),
      );
      return;
    }

    if (needsUpi && !_formKey.currentState!.validate()) return;
    if (needsSelfie && _capturedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture a live selfie before submitting.')),
      );
      return;
    }

    setState(() => _submitting = true);

    var upiSubmitted = !needsUpi;
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
      if (!upiOk) {
        setState(() => _submitting = false);
        if (kyc.error != null) return;
      } else {
        upiSubmitted = true;
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
      if (!selfieOk) return;
    } else {
      setState(() => _submitting = false);
    }

    if (!mounted) return;
    await kyc.loadKycStatus();
    if (!mounted) return;
    if (_awaitingAdminReview(kyc.status)) {
      await _releaseCamera();
    }

    final message = upiSubmitted && needsSelfie
        ? 'Submitted for admin verification. Our team will review your UPI and selfie within 24 hours.'
        : needsSelfie
            ? 'Selfie submitted for admin verification.'
            : 'UPI submitted for admin verification.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _startPolling();
    setState(() {});
  }

  Widget _buildSelfiePreview() {
    if (_capturedBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_capturedBytes!, fit: BoxFit.cover, width: double.infinity),
      );
    }

    if (_cameraReady && _controller != null && _controller!.value.isInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CameraPreview(_controller!),
      );
    }

    final showTapToStart = !_cameraInitializing && !_cameraReady;
    final desktopPrompt = _isDesktop && _capturedBytes == null;
    return GestureDetector(
      onTap: (showTapToStart || desktopPrompt) ? _openSelfieCapture : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ColoredBox(
          color: Colors.black,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_cameraInitializing)
                    const CircularProgressIndicator(color: AppColors.brandOrange)
                  else
                    const Icon(Icons.videocam_outlined, color: AppColors.brandOrange, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    _cameraError ??
                        (desktopPrompt
                            ? 'Tap here to open the camera and capture your selfie.'
                            : showTapToStart
                                ? 'Tap here to turn on your camera.'
                                : 'Starting front camera…'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), height: 1.4),
                  ),
                  if (_cameraError != null && !_cameraInitializing) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _isDesktop ? _openSelfieCapture : _startLiveCamera,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandPrimary,
                        side: const BorderSide(color: AppColors.brandPrimary),
                      ),
                      child: Text(_isDesktop ? 'Open live camera' : 'Turn on camera'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<KycFlowProvider>(
      builder: (context, kyc, _) {
        final s = kyc.status;
        final needsUpi = _stillNeedsUpi(s);
        final needsSelfie = _stillNeedsSelfie(s);
        final awaitingReview = _awaitingAdminReview(s) && !needsUpi && !needsSelfie;
        final showActions = needsUpi || needsSelfie;
        final bankBlocked = !s.bankReadyForIdentity && (needsUpi || needsSelfie);
        final bankError = (kyc.error ?? '').toLowerCase().contains('bank verification');

        void goBack() {
          OnboardingFlowNavigator.goToPreviousKycStep(
            context,
            kyc,
            currentRoute: AppRoutes.identityVerification,
          );
        }

        return KycStepScaffold(
          title: 'UPI & selfie verification',
          subtitle:
              'Enter your UPI ID and capture a live selfie. Both are sent to our compliance team for manual approval.',
          stepLabel: 'FINAL IDENTITY CHECK',
          stepIndex: 5,
          totalSteps: 5,
          icon: Icons.face_retouching_natural_outlined,
          onBack: goBack,
          footer: showActions
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bankBlocked || bankError) ...[
                          OutlinedButton(
                            onPressed: goBack,
                            child: const Text('Back to Bank Verification'),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (needsSelfie) ...[
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _submitting
                                      ? null
                                      : () async {
                                          if (_capturedBytes != null) {
                                            await _retakeSelfie();
                                          } else {
                                            await _openSelfieCapture();
                                          }
                                        },
                                  child: Text(
                                    _capturedBytes == null
                                        ? (_isDesktop
                                            ? 'Open live camera'
                                            : (_cameraReady ? 'Capture selfie' : 'Turn on camera'))
                                        : 'Retake',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        PrimaryButton(
                          label: _submitting ? 'Submitting…' : 'Submit for verification',
                          onPressed: (bankBlocked || bankError || _submitting || kyc.isLoading) ? null : _submitAll,
                        ),
                      ],
                    ),
                  ),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              if (kyc.error != null) ...[
                KycErrorBanner(message: kyc.error!),
                const SizedBox(height: 12),
              ],
              if (bankBlocked || bankError) ...[
                KycInfoCard(
                  tone: KycInfoTone.warning,
                  title: 'Bank verification required',
                  message: bankBlocked
                      ? 'You saved bank details, but live verification (Eko) has not completed yet. '
                          'Go back to Bank Verification and tap Verify Bank Account before submitting UPI.'
                      : 'Complete bank verification before submitting UPI. Return to the bank step and verify your account.',
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Go to Bank Verification',
                  onPressed: () => context.go(AppRoutes.bankVerificationKyc),
                ),
                const SizedBox(height: 16),
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
                  KycInfoCard(
                    tone: KycInfoTone.warning,
                    title: 'Final review in progress',
                    message: s.bankVerified
                        ? 'UPI and selfie are verified. An admin will complete your account verification shortly.'
                        : 'UPI and selfie are verified. Your bank account still needs admin approval — '
                            'once verified, an admin will complete your account verification.',
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
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: _selfiePreviewMaxHeight),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _buildSelfiePreview(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position your face in the frame. Live camera only — gallery uploads are not accepted. Our team manually verifies your selfie.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          height: 1.4,
                        ),
                  ),
                ] else if (s.selfieVerified)
                  const KycInfoCard(
                    tone: KycInfoTone.success,
                    title: 'Selfie verified',
                    message: 'Your selfie has been approved.',
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
