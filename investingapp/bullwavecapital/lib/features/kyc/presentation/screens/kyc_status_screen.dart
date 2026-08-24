import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/kyc_models.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/kyc_widgets.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KycFlowProvider>().loadStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      appBar: const CustomAppBar(title: 'KYC Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          if (kyc.isLoading && kyc.status == KycStatusModel.empty) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.brandOrange),
            );
          }

          final s = kyc.status;
          return RefreshIndicator(
            color: AppColors.brandOrange,
            onRefresh: kyc.loadStatus,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Verification Progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    KycStatusBadge(status: s.overallStatus),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Complete all steps to start investing and withdrawing.',
                  style: TextStyle(color: colors.textSecondary),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      KycStepTile(
                        title: 'Mobile Verified',
                        subtitle: s.mobileVerified
                            ? 'OTP verified'
                            : 'Login with phone OTP',
                        completed: s.mobileVerified,
                      ),
                      KycStepTile(
                        title: 'PAN Verified',
                        subtitle: s.panVerified
                            ? '${s.panName} • ${s.panNumberMasked}'
                            : 'Verify your PAN',
                        completed: s.panVerified,
                      ),
                      KycStepTile(
                        title: 'Aadhaar Verified',
                        subtitle: s.aadhaarVerified
                            ? (s.aadhaarName.isEmpty
                                  ? 'Verified through DigiLocker'
                                  : '${s.aadhaarName} • DigiLocker')
                            : 'Verify Aadhaar through DigiLocker',
                        completed: s.aadhaarVerified,
                      ),
                      KycStepTile(
                        title: 'Bank Verified',
                        subtitle: s.bankVerified
                            ? '${s.bankName} • ${s.bankAccountMasked}'
                            : 'Verify bank account via Eko',
                        completed: s.bankVerified,
                      ),
                      KycStepTile(
                        title: 'Selfie Verified',
                        subtitle: s.selfieVerified
                            ? 'Live selfie approved'
                            : s.selfieReviewPending
                            ? 'Under manual review (up to 24h)'
                            : s.selfieReviewRejected
                            ? 'Retake required'
                            : 'Capture a live selfie',
                        completed: s.selfieVerified,
                      ),
                      if (kyc.upiRequired)
                        KycStepTile(
                          title: 'UPI Verified',
                          subtitle: s.upiVerified
                              ? (s.upiName.isEmpty
                                    ? s.upiVpaMasked
                                    : '${s.upiName} • ${s.upiVpaMasked}')
                              : s.paymentReviewPending
                              ? 'Under manual review (up to 24h)'
                              : 'Verify your UPI ID',
                          completed: s.upiVerified,
                        ),
                      KycStepTile(
                        title: 'Name Match Passed',
                        subtitle: s.nameMatchPassed
                            ? '${s.nameMatchResult} (${s.nameMatchScore.toStringAsFixed(0)}%)'
                            : 'Match PAN name with bank records',
                        completed: s.nameMatchPassed,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                if (kyc.error != null) ...[
                  const SizedBox(height: 16),
                  KycErrorBanner(message: kyc.error!),
                ],
                const SizedBox(height: 24),
                if (kyc.upiRequired &&
                    (s.paymentReviewPending ||
                        s.bankDraftReady ||
                        !s.upiVerified) &&
                    s.bankVerified &&
                    !s.upiVerified)
                  PrimaryButton(
                    label: s.paymentReviewPending
                        ? 'View review status'
                        : 'Continue to identity verification',
                    onPressed: () =>
                        context.push(AppRoutes.identityVerification),
                  )
                else
                  PrimaryButton(
                    label: kyc.isFullyVerified
                        ? 'Go to Home'
                        : OnboardingFlowNavigator.labelForNextKycStep(kyc),
                    onPressed: () {
                      if (kyc.isFullyVerified) {
                        context.go(AppRoutes.home);
                      } else {
                        OnboardingFlowNavigator.goToNextKycStep(context, kyc);
                      }
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
