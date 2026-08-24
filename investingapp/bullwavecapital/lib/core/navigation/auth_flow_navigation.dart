import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/paper_only_mode.dart';
import '../constants/routes.dart';
import '../api/refresh_providers.dart';
import '../security/app_lock_provider.dart';
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

    final kycComplete = PaperOnlyMode.enabled
        ? kyc.hasPhase1Identity
        : kyc.isFullyVerified;
    if (auth.isRegistrationFlow && !kycComplete) {
      router.go(
        OnboardingFlowNavigator.nextIncompleteKycStep(kyc) ??
            AppRoutes.panVerification,
      );
      unawaited(refreshAllProviders(context));
      return;
    }

    await auth.markSignedInSession();
    await context.read<AppLockProvider>().init(userId: auth.user?.id);

    final appLock = context.read<AppLockProvider>();
    if (!appLock.hasMpin) {
      router.go('${AppRoutes.setupMpin}?optional=true');
      unawaited(refreshAllProviders(context));
      return;
    }

    if (appLock.isEnabled) {
      router.go(AppRoutes.appLock);
      unawaited(refreshAllProviders(context));
      return;
    }

    appLock.markUnlocked();
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
