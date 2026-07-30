import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

class NameMatchScreen extends StatefulWidget {
  const NameMatchScreen({super.key});

  @override
  State<NameMatchScreen> createState() => _NameMatchScreenState();
}

class _NameMatchScreenState extends State<NameMatchScreen> {
  bool _attempted = false;
  bool _routing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final kyc = context.read<KycFlowProvider>();
    await kyc.loadKycStatus();
    if (!mounted) return;

    final s = kyc.status;
    if (!s.selfieVerified) {
      context.go(AppRoutes.selfieVerification);
      return;
    }
    if (s.nameMatchPassed) {
      OnboardingFlowNavigator.goToNextKycStep(context, kyc);
      return;
    }

    setState(() => _routing = false);
  }

  Future<void> _runMatch() async {
    final kyc = context.read<KycFlowProvider>();
    await kyc.runNameMatch();
    if (!mounted) return;
    setState(() => _attempted = true);
    if (kyc.status.nameMatchPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name match passed. Welcome to BullWave!')),
      );
      OnboardingFlowNavigator.goToNextKycStep(context, kyc);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: const CustomAppBar(title: 'Name Match'),
      body: _routing
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandOrange))
          : Consumer<KycFlowProvider>(
              builder: (context, kyc, _) {
                final s = kyc.status;
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Compare PAN & Bank names',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We compare your verified PAN name with the name on your bank account.',
                      style: TextStyle(color: colors.textSecondary, height: 1.45),
                    ),
                    const SizedBox(height: 20),
                    _CompareCard(label: 'PAN Name', value: s.panName, colors: colors),
                    const SizedBox(height: 12),
                    _CompareCard(
                      label: 'Bank Name',
                      value: s.nameAtBank.isNotEmpty ? s.nameAtBank : s.accountHolderName,
                      colors: colors,
                    ),
                    const SizedBox(height: 24),
                    if (s.nameMatchPassed) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.green.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.verified_rounded, color: AppColors.green, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              'Verified • ${s.nameMatchResult}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text('Match score: ${s.nameMatchScore.toStringAsFixed(0)}%'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(
                        label: 'Go to Home',
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                    ] else if (_attempted) ...[
                      KycErrorBanner(
                        message: kyc.error ??
                            'Names do not match. Update bank or PAN details and retry.',
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(label: 'Retry', onPressed: _runMatch),
                    ] else ...[
                      if (kyc.error != null) ...[
                        KycErrorBanner(message: kyc.error!),
                        const SizedBox(height: 16),
                      ],
                      PrimaryButton(
                        label: kyc.isLoading ? 'Checking…' : 'Run Name Match',
                        onPressed: kyc.isLoading ? null : _runMatch,
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  final String label;
  final String value;
  final AppThemeExtension colors;

  const _CompareCard({
    required this.label,
    required this.value,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '—' : value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
