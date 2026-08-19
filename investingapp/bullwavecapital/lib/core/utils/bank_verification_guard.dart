import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/paper_only_mode.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

import 'investment_risk_guard.dart';
import '../navigation/onboarding_flow_navigator.dart';

import '../constants/routes.dart';

/// Returns true when KYC is fully verified (or user completes flow).
Future<bool> ensureBankVerified(BuildContext context) async {
  final kyc = context.read<KycFlowProvider>();
  await kyc.loadStatus();

  if (PaperOnlyMode.enabled) {
    if (kyc.hasPhase1Identity) {
      if (!context.mounted) return false;
      return ensureInvestmentRiskAcknowledged(context);
    }
    if (!context.mounted) return false;
    final next = OnboardingFlowNavigator.nextIncompleteKycStep(kyc) ??
        AppRoutes.panVerification;
    await context.push(next);
    await kyc.loadStatus();
    if (!context.mounted) return false;
    if (kyc.hasPhase1Identity) {
      return ensureInvestmentRiskAcknowledged(context);
    }
    return false;
  }

  if (kyc.isFullyVerified) {
    if (!context.mounted) return false;
    return ensureInvestmentRiskAcknowledged(context);
  }
  if (!context.mounted) return false;
  final done = await context.push<bool>(kyc.verificationRoute);
  await kyc.loadStatus();
  if (!context.mounted) return false;
  if (done == true || kyc.isFullyVerified) {
    return ensureInvestmentRiskAcknowledged(context);
  }
  return false;
}
