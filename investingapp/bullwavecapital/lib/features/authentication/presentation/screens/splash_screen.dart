import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/splash_animation.dart';

/// Entry screen — splash → onboarding (first launch) → login → OTP → home.
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
    final app = context.read<AppProvider>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      auth.prepareForLoginScreen(),
    ]);
    if (!mounted) return;

    if (DevConfig.enabled && auth.isAuthenticated) {
      unawaited(refreshAllProviders(context));
      context.go(AppRoutes.home);
      return;
    }

    context.go(
      OnboardingFlowNavigator.routeAfterSplash(
        hasCompletedOnboarding: app.hasCompletedOnboarding,
        isAuthenticated: auth.isAuthenticated,
        auth: auth,
        kyc: context.read<KycFlowProvider>(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SplashAnimation();
  }
}
