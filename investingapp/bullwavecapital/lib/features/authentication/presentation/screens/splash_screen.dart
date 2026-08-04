import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/constants/routes.dart';
import '../provider/auth_provider.dart';
import '../widgets/splash_animation.dart';

/// Entry screen — always opens phone login (Home only in dev shortcut).
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

    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashAnimation();
  }
}
