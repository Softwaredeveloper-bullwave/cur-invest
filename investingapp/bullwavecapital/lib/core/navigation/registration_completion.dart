import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/token_storage.dart';
import '../constants/routes.dart';
import '../config/paper_only_mode.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Ends the registration funnel — unlocks Home after KYC is complete.
class RegistrationCompletion {
  RegistrationCompletion._();

  static bool isRegistrationComplete(KycFlowProvider kyc) {
    if (PaperOnlyMode.enabled) return kyc.hasPhase1Identity;
    return kyc.isFullyVerified;
  }

  /// New user finished all KYC steps — enter the app.
  static Future<void> finishAndGoHome(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    auth.endRegistration();
    await auth.markSignedInSession();
    await TokenStorage.setRegistrationInProgress(false);
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }

  static Future<void> maybeFinishRegistration(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    if (!isRegistrationComplete(kyc)) return;
    if (auth.isRegistrationFlow ||
        !(await TokenStorage.hasSignedInSession())) {
      await finishAndGoHome(context);
    }
  }
}
