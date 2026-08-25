import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/api/token_storage.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/security/app_lock_provider.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/splash_animation.dart';

/// Entry screen — splash → session restore → app lock → onboarding / login / home.
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
    final appLock = context.read<AppLockProvider>();

    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2800)),
      auth.tryRestoreSession(),
    ]);
    if (!mounted) return;

    await appLock.init(userId: auth.user?.id);
    if (!mounted) return;

    final kyc = context.read<KycFlowProvider>();
    if (auth.isAuthenticated) {
      await kyc.loadStatus();
      if (!mounted) return;
    }

    if (DevConfig.enabled && auth.isAuthenticated) {
      appLock.markUnlocked();
      unawaited(refreshAllProviders(context));
      context.go(AppRoutes.home);
      return;
    }

    if (auth.canAutoEnterApp && appLock.requiresUnlock) {
      context.go(AppRoutes.appLock);
      return;
    }

    if (auth.canAutoEnterApp) {
      appLock.markUnlocked();
    }

    var next = OnboardingFlowNavigator.routeAfterSplash(
      hasCompletedOnboarding: app.hasCompletedOnboarding,
      isAuthenticated: auth.isAuthenticated,
      auth: auth,
      kyc: kyc,
    );
    if (auth.isAuthenticated &&
        next == AppRoutes.home &&
        !(await TokenStorage.hasMarketPreferenceCompleted())) {
      next = AppRoutes.marketInterest;
    }
    if (!mounted) return;
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashAnimation();
  }
}
