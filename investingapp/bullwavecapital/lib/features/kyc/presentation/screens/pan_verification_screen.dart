import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/storage/legal_consent_storage.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/legal_acceptance_widgets.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/bank_form_widgets.dart';
import '../widgets/kyc_widgets.dart';

class PanVerificationScreen extends StatefulWidget {
  const PanVerificationScreen({super.key});

  @override
  State<PanVerificationScreen> createState() => _PanVerificationScreenState();
}

class _PanVerificationScreenState extends State<PanVerificationScreen> {
  final _panController = TextEditingController();
  final _nameController = TextEditingController();
  bool _kycConsent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final stored = await LegalConsentStorage.hasKycConsent();
      if (mounted) setState(() => _kycConsent = stored);
      if (!mounted) return;
      // Refresh from the database so an already-verified PAN shows the
      // verified state immediately instead of asking to verify again.
      context.read<KycFlowProvider>().loadKycStatus();
      if (!mounted) return;
      final name = context.read<AuthProvider>().user?.name ?? '';
      if (name.isNotEmpty && _nameController.text.isEmpty) {
        _nameController.text = name;
      }
    });
  }

  @override
  void dispose() {
    _panController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_kycConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please authorize KYC verification to continue.'),
        ),
      );
      return;
    }
    final pan = _panController.text.toUpperCase();
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid PAN number')));
      return;
    }
    final kyc = context.read<KycFlowProvider>();
    final verified = await kyc.verifyPan(pan, holderName: _nameController.text);
    if (!mounted || !verified) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PAN verified successfully.')));
    OnboardingFlowNavigator.goToNextKycStep(context, kyc);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'PAN Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final s = kyc.status;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Verify your PAN',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Your PAN is verified in real time against Income Tax Department records. '
                'Use the exact legal name printed on your PAN card.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              if (!s.panVerified) ...[
                KycConsentCard(
                  value: _kycConsent,
                  onChanged: (v) async {
                    setState(() => _kycConsent = v);
                    await LegalConsentStorage.setKycConsent(v);
                  },
                ),
                const SizedBox(height: 20),
                AppTextField(
                  controller: _panController,
                  label: 'PAN Number',
                  hint: 'ABCDE1234F',
                  inputFormatters: [
                    PanInputFormatter(),
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (v) =>
                      _panController.value = _panController.value.copyWith(
                        text: v.toUpperCase(),
                        selection: TextSelection.collapsed(offset: v.length),
                      ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name (as on PAN)',
                  hint: 'Legal name',
                  textCapitalization: TextCapitalization.words,
                ),
                if (kyc.error != null) ...[
                  const SizedBox(height: 16),
                  KycErrorBanner(message: kyc.error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: kyc.isLoading ? 'Verifying…' : 'Verify PAN',
                  onPressed: kyc.isLoading || !_kycConsent ? null : _verify,
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
                        'PAN Verified',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoRow('Full Name', s.panName),
                      _InfoRow('PAN', s.panNumberMasked),
                      _InfoRow('Status', s.panStatus),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
