import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
import '../api/refresh_providers.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import 'onboarding_flow_navigator.dart';
import 'registration_completion.dart';

/// Central post-auth navigation — sign-in vs registration stay separate.
class AuthFlowNavigation {
  AuthFlowNavigation._();

  static Future<void> afterPhoneOtp(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    final router = GoRouter.of(context);

    if (!auth.hasCompletedRegistration) {
      if (!auth.isRegistrationFlow) auth.beginRegistration();
      await kyc.loadStatus();
      if (!context.mounted) return;
      router.go(OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc));
      unawaited(refreshAllProviders(context));
      return;
    }

    await kyc.loadStatus();
    if (!context.mounted) return;

    if (auth.isRegistrationFlow && !kyc.isFullyVerified) {
      router.go(
        OnboardingFlowNavigator.nextIncompleteKycStep(kyc) ??
            AppRoutes.panVerification,
      );
      unawaited(refreshAllProviders(context));
      return;
    }

    await auth.markSignedInSession();
    router.go(OnboardingFlowNavigator.routeForReturningUser(kyc));
    unawaited(refreshAllProviders(context));
  }

  static Future<void> afterEmailOtp(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    final router = GoRouter.of(context);

    await kyc.loadStatus();
    if (!context.mounted) return;
    router.go(OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc));
    unawaited(refreshAllProviders(context));
  }

  static Future<void> afterProfileComplete(BuildContext context) async {
    if (!context.mounted) return;
    final kyc = context.read<KycFlowProvider>();
    final router = GoRouter.of(context);

    await kyc.loadStatus();
    if (!context.mounted) return;
    router.go(OnboardingFlowNavigator.routeAfterProfileComplete(kyc));
    unawaited(refreshAllProviders(context));
  }

  static Future<void> afterKycMilestone(BuildContext context) async {
    await RegistrationCompletion.maybeFinishRegistration(context);
  }
}
