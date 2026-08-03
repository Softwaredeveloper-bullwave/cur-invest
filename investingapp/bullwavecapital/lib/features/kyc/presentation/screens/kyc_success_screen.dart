import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/registration_completion.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';

class KycSuccessScreen extends StatelessWidget {
  const KycSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finishingRegistration = auth.isRegistrationFlow;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user, color: AppColors.success, size: 72),
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              Text(
                finishingRegistration ? 'Verification complete' : 'KYC Verified!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                finishingRegistration
                    ? 'Your identity verification is complete. Sign in with your registered mobile number to start using BullWave.'
                    : 'Your PAN, bank account, and name have been verified. You can now explore markets and start investing.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingXl),
              PrimaryButton(
                label: finishingRegistration ? 'Continue to sign in' : 'Start Investing',
                onPressed: () async {
                  if (finishingRegistration) {
                    await RegistrationCompletion.returnToLoginAfterRegistration(context);
                    return;
                  }
                  if (context.mounted) context.go(AppRoutes.invest);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
