import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

enum _DigiLockerStep { ready, waiting, verified }

class AadhaarVerificationScreen extends StatefulWidget {
  const AadhaarVerificationScreen({super.key});

  @override
  State<AadhaarVerificationScreen> createState() =>
      _AadhaarVerificationScreenState();
}

class _AadhaarVerificationScreenState extends State<AadhaarVerificationScreen>
    with WidgetsBindingObserver {
  _DigiLockerStep _step = _DigiLockerStep.ready;
  bool _consentGiven = false;
  bool _browserOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _browserOpened &&
        _step == _DigiLockerStep.waiting) {
      _checkStatus(silent: true);
    }
  }

  Future<void> _restoreStatus() async {
    if (!mounted) return;
    final kyc = context.read<KycFlowProvider>();
    await kyc.loadKycStatus();
    if (!mounted) return;

    final query = GoRouterState.of(context).uri.queryParameters;
    final fromCallback = query['digilocker'];
    final verificationId = query['verification_id'] ?? query['verificationId'];

    if (fromCallback == '1' || fromCallback == 'true') {
      setState(() => _step = _DigiLockerStep.waiting);
      await _checkStatus(silent: true, verificationId: verificationId);
      return;
    }

    if (verificationId != null && verificationId.isNotEmpty) {
      setState(() => _step = _DigiLockerStep.waiting);
      await _checkStatus(silent: true, verificationId: verificationId);
      return;
    }

    setState(() {
      if (kyc.status.aadhaarVerified) {
        _step = _DigiLockerStep.verified;
      } else if (kyc.status.aadhaarDigiLockerPending) {
        _step = _DigiLockerStep.waiting;
      }
    });
  }

  Future<void> _startDigiLocker() async {
    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please consent to DigiLocker Aadhaar verification'),
        ),
      );
      return;
    }

    final kyc = context.read<KycFlowProvider>();
    final url = await kyc.startAadhaarDigiLocker();
    if (!mounted || url == null) return;

    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !const {'https', 'http'}.contains(uri.scheme.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eko returned an invalid DigiLocker URL')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open DigiLocker')),
      );
      return;
    }
    setState(() {
      _browserOpened = true;
      _step = _DigiLockerStep.waiting;
    });
  }

  Future<void> _resumeDigiLocker() async {
    final url = context.read<KycFlowProvider>().status.aadhaarDigiLockerUrl;
    if (url.isEmpty) {
      setState(() => _step = _DigiLockerStep.ready);
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (mounted && opened) setState(() => _browserOpened = true);
  }

  Future<void> _checkStatus({bool silent = false, String? verificationId}) async {
    final verified = await context.read<KycFlowProvider>().checkAadhaarDigiLocker(
          verificationId: verificationId,
        );
    if (!mounted) return;
    if (verified) {
      setState(() => _step = _DigiLockerStep.verified);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aadhaar verified successfully.')),
        );
      }
      OnboardingFlowNavigator.goToNextKycStep(
        context,
        context.read<KycFlowProvider>(),
      );
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification is still pending. Complete consent in DigiLocker and try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const CustomAppBar(title: 'Aadhaar Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final status = kyc.status;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.brandOrange,
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                _step == _DigiLockerStep.verified
                    ? 'Aadhaar verified'
                    : 'Verify with DigiLocker',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _step == _DigiLockerStep.waiting
                    ? 'Complete Aadhaar document consent in DigiLocker, then return here to check the result.'
                    : _step == _DigiLockerStep.verified
                        ? 'Your identity was securely verified using the Aadhaar document shared through DigiLocker.'
                        : 'DigiLocker will ask you to sign in and consent to sharing your Aadhaar for KYC.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              if (kyc.error != null) ...[
                KycErrorBanner(message: kyc.error!),
                const SizedBox(height: 16),
              ],
              if (_step == _DigiLockerStep.ready) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandOrange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _JourneyItem('Sign in securely on DigiLocker'),
                      _JourneyItem('Select and consent to share Aadhaar'),
                      _JourneyItem('Return to BullWave to finish KYC'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _consentGiven,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: kyc.isLoading
                      ? null
                      : (value) =>
                          setState(() => _consentGiven = value ?? false),
                  title: const Text(
                    'I consent to verify my identity by sharing my Aadhaar through DigiLocker.',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: const Text(
                    'BullWave does not ask for or store your full Aadhaar number.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: kyc.isLoading
                      ? 'Creating secure session…'
                      : 'Continue with DigiLocker',
                  onPressed: kyc.isLoading ? null : _startDigiLocker,
                ),
              ] else if (_step == _DigiLockerStep.waiting) ...[
                const _WaitingCard(),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: kyc.isLoading
                      ? 'Checking verification…'
                      : 'Check verification status',
                  onPressed:
                      kyc.isLoading ? null : () => _checkStatus(silent: false),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: kyc.isLoading ? null : _resumeDigiLocker,
                  child: const Text('Open DigiLocker again'),
                ),
                if (kyc.error != null &&
                    (kyc.error!.toLowerCase().contains('expired') ||
                        kyc.error!.toLowerCase().contains('endpoint'))) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Your previous DigiLocker session is no longer valid. Tap '
                    '“Start a new verification” below, complete consent again, '
                    'then return here — you should land back in this app, not bullwave.in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                TextButton(
                  onPressed: kyc.isLoading
                      ? null
                      : () => setState(() {
                            _consentGiven = false;
                            _step = _DigiLockerStep.ready;
                          }),
                  child: const Text('Start a new verification'),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Verified through DigiLocker',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      if (status.aadhaarName.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(status.aadhaarName),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: OnboardingFlowNavigator.labelForNextKycStep(kyc),
                  onPressed: () =>
                      OnboardingFlowNavigator.goToNextKycStep(context, kyc),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _JourneyItem extends StatelessWidget {
  const _JourneyItem(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: AppColors.brandOrange,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppColors.brandOrange),
          SizedBox(height: 16),
          Text(
            'Waiting for DigiLocker consent',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
