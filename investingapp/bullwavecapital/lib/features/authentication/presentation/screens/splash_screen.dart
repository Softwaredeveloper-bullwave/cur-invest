import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/splash_animation.dart';

/// Entry screen — restores session to Home, or opens Login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateNext();
  }

  Future<void> _navigateNext() async {
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      auth.tryRestoreSession(),
    ]);
    if (!mounted) return;

    if (auth.isAuthenticated && auth.hasCompletedRegistration) {
      auth.beginSignIn();
      await kyc.loadStatus();
      if (!mounted) return;
      unawaited(refreshAllProviders(context));
      context.go(AppRoutes.home);
      return;
    }

    if (auth.isAuthenticated && auth.needsRegistrationFlow) {
      auth.beginRegistration();
      await kyc.loadStatus();
      if (!mounted) return;
      unawaited(refreshAllProviders(context));
      context.go(
        OnboardingFlowNavigator.routeAfterAuthentication(auth, kyc),
      );
      return;
    }

    auth.beginSignIn();
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashAnimation();
  }
}
