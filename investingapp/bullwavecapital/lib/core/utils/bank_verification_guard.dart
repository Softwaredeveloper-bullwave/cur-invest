import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Returns true when KYC is fully verified (or user completes flow).
Future<bool> ensureBankVerified(BuildContext context) async {
  final kyc = context.read<KycFlowProvider>();
  await kyc.loadStatus();
  if (kyc.isFullyVerified) return true;
  if (!context.mounted) return false;
  final done = await context.push<bool>(kyc.verificationRoute);
  await kyc.loadStatus();
  return done == true || kyc.isFullyVerified;
}
