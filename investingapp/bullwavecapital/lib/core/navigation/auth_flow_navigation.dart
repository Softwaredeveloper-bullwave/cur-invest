import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/refresh_providers.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import 'onboarding_flow_navigator.dart';

/// Central post-auth navigation — avoids blank screens during GoRouter redirects.
class AuthFlowNavigation {
  AuthFlowNavigation._();

  /// Email and profile setup never depend on KYC status — navigate immediately.
  static bool _needsAuthSetupOnly(AuthProvider auth) =>
      auth.needsEmailVerification || auth.needsProfileSetup;

  static Future<void> afterPhoneOtp(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    final router = GoRouter.of(context);

    if (_needsAuthSetupOnly(auth)) {
      router.go(OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc));
      unawaited(kyc.loadStatus());
      unawaited(refreshAllProviders(context));
      return;
    }

    await kyc.loadStatus();
    if (!context.mounted) return;
    router.go(OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc));
    unawaited(refreshAllProviders(context));
  }

  static Future<void> afterEmailOtp(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    final router = GoRouter.of(context);

    if (auth.needsProfileSetup) {
      router.go(OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc));
      unawaited(kyc.loadStatus());
      unawaited(refreshAllProviders(context));
      return;
    }

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
}
