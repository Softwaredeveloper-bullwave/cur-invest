import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

import 'investment_risk_guard.dart';

/// Returns true when KYC is fully verified (or user completes flow).
Future<bool> ensureBankVerified(BuildContext context) async {
  final kyc = context.read<KycFlowProvider>();
  await kyc.loadStatus();
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
