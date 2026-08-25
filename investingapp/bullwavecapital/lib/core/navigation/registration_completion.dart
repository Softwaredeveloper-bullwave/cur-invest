import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../api/bullwave_api.dart';
import '../api/token_storage.dart';
import '../constants/routes.dart';
import '../config/paper_only_mode.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/crypto/presentation/provider/crypto_market_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Ends the registration funnel — unlocks Home after KYC is complete.
class RegistrationCompletion {
  RegistrationCompletion._();

  static bool isRegistrationComplete(KycFlowProvider kyc) {
    if (PaperOnlyMode.enabled) return kyc.hasPhase1Identity;
    return kyc.isFullyVerified;
  }

  static Future<bool> _needsMarketInterest() async {
    if (await TokenStorage.hasMarketPreferenceCompleted()) return false;
    try {
      final pref = await BullwaveApi.instance.getMarketPreference();
      if (pref.hasCompletedSelection) {
        await TokenStorage.setMarketPreferenceCompleted(true);
        return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// New user finished all KYC steps — enter the app.
  static Future<void> finishAndGoHome(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    auth.endRegistration();
    await auth.markSignedInSession();
    await TokenStorage.setRegistrationInProgress(false);
    if (!context.mounted) return;

    if (await _needsMarketInterest()) {
      if (!context.mounted) return;
      context.go(AppRoutes.marketInterest);
      return;
    }

    if (!context.mounted) return;
    await context.read<CryptoMarketProvider>().loadPreference();
    if (!context.mounted) return;
    context.go(AppRoutes.home);
  }

  static Future<void> maybeFinishRegistration(BuildContext context) async {
    if (!context.mounted) return;
    final auth = context.read<AuthProvider>();
    final kyc = context.read<KycFlowProvider>();
    if (!isRegistrationComplete(kyc)) return;
    final hasSession = await TokenStorage.hasSignedInSession();
    if (!context.mounted) return;
    if (auth.isRegistrationFlow || !hasSession) {
      await finishAndGoHome(context);
    }
  }
}
