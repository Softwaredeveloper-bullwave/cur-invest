import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Ends the registration funnel by signing out and returning to the login screen.
class RegistrationCompletion {
  RegistrationCompletion._();

  static bool isRegistrationComplete(KycFlowProvider kyc) => kyc.isFullyVerified;

  static Future<void> returnToLoginAfterRegistration(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isRegistrationFlow) return;

    auth.endRegistration();
    await auth.logout();
    if (!context.mounted) return;
    context.go('${AppRoutes.login}?registered=1');
  }

  static Future<void> maybeFinishRegistration(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    if (!auth.isRegistrationFlow || !isRegistrationComplete(kyc)) return;
    await returnToLoginAfterRegistration(context);
  }
}
