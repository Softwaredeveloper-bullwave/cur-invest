import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/paper_only_mode.dart';
import '../constants/routes.dart';
import '../navigation/app_access_policy.dart';
import '../navigation/onboarding_flow_navigator.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

/// Push a full-screen route above the bottom tab shell.
Future<void> pushOverShell(BuildContext context, String location) async {
  final path = Uri.parse(location).path;

  if (PaperOnlyMode.enabled && AppAccessPolicy.requiresKyc(path)) {
    final kyc = context.read<KycFlowProvider>();
    if (!kyc.hasPhase1Identity) {
      final next =
          OnboardingFlowNavigator.nextIncompleteKycStep(kyc) ??
          AppRoutes.panVerification;
      if (path != next) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Complete phone, email, PAN, Aadhaar and bank verification first.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      context.push(next);
      return;
    }
  }

  context.push(location);
}
