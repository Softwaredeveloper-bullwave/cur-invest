import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/routes.dart';
import '../config/paper_only_mode.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/domain/kyc_models.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import 'registration_completion.dart';

/// Splash → onboarding → phone OTP → email OTP → profile → KYC steps → home.
class OnboardingFlowNavigator {
  OnboardingFlowNavigator._();

  static const _kycStepPaths = {
    AppRoutes.kyc,
    AppRoutes.kycStatus,
    AppRoutes.kycSubmit,
    AppRoutes.kycPending,
    AppRoutes.kycRejected,
    AppRoutes.panVerification,
    AppRoutes.aadhaarVerificationKyc,
    AppRoutes.bankVerificationKyc,
    AppRoutes.selfieVerification,
    AppRoutes.upiVerification,
    AppRoutes.identityVerification,
    AppRoutes.nameMatch,
    AppRoutes.kycSuccess,
    AppRoutes.fnoVerification,
    AppRoutes.bankVerification,
    AppRoutes.completeProfile,
    AppRoutes.verifyEmail,
    AppRoutes.verifyEmailOtp,
  };

  static const _shellPaths = {
    AppRoutes.home,
    AppRoutes.invest,
    AppRoutes.portfolio,
    AppRoutes.wallet,
    AppRoutes.profile,
  };

  static bool isKycOrAuthSetupPath(String path) => _kycStepPaths.contains(path);

  static bool shouldBlockShellUntilKycComplete(String path) =>
      _shellPaths.contains(path);

  static String routeAfterSplash({
    required bool hasCompletedOnboarding,
    required bool isAuthenticated,
    required AuthProvider auth,
    required KycFlowProvider kyc,
  }) {
    if (!hasCompletedOnboarding) return AppRoutes.onboarding;
    if (!isAuthenticated) return AppRoutes.login;
    return routeAfterAuthentication(auth, kyc);
  }

  static String routeAfterAuthentication(
    AuthProvider auth,
    KycFlowProvider kyc,
  ) {
    final profile = profileCompletionRoute(auth);
    if (profile != null) return profile;
    return routeForReturningUser(kyc);
  }

  /// Next profile / email step, or null when profile setup is complete.
  static String? profileCompletionRoute(AuthProvider auth) {
    if (!auth.needsRegistrationFlow) return null;
    if (auth.needsEmailVerification) {
      return auth.needsEmailOtpEntry
          ? AppRoutes.verifyEmailOtp
          : AppRoutes.verifyEmail;
    }
    if (auth.needsProfileSetup) return AppRoutes.completeProfile;
    return AppRoutes.verifyEmail;
  }

  /// Registered returning user — home when Phase 1 identity is done (paper mode).
  static String routeForReturningUser(KycFlowProvider kyc) {
    if (PaperOnlyMode.enabled && !kyc.hasPhase1Identity) {
      return nextIncompleteKycStep(kyc) ?? AppRoutes.panVerification;
    }
    return AppRoutes.home;
  }

  static String routeAfterProfileComplete(KycFlowProvider kyc) {
    return nextIncompleteKycStep(kyc) ?? AppRoutes.panVerification;
  }

  /// UPI + live selfie are one manual admin-review step.
  static bool _identityStepComplete(
    KycStatusModel status,
    bool upiRequired,
  ) {
    final upiDone = !upiRequired ||
        status.upiVerified ||
        status.paymentReviewPending ||
        (status.upiManual &&
            status.upiStatus == 'pending' &&
            status.upiVpaMasked.isNotEmpty);
    final selfieDone =
        status.selfieVerified || status.selfieReviewPending;
    return upiDone && selfieDone;
  }

  /// Ordered onboarding KYC: PAN → Aadhaar → Bank → UPI+Selfie → Home.
  static String? nextIncompleteKycStep(KycFlowProvider kyc) {
    final status = kyc.status;

    if (!status.panVerified) return AppRoutes.panVerification;
    if (!status.aadhaarVerified) return AppRoutes.aadhaarVerificationKyc;

    final bankDone = status.bankVerified ||
        status.bankReviewPending ||
        status.bankDraftReady;
    if (!bankDone) return AppRoutes.bankVerificationKyc;

    // Phase 1 — identity verified through bank; skip UPI/selfie/final approval.
    if (PaperOnlyMode.enabled) return null;

    if (!_identityStepComplete(status, kyc.upiRequired)) {
      return AppRoutes.identityVerification;
    }

    if (status.manualFinalApprovalRequired && !status.finalKycApproved) {
      return AppRoutes.kycPending;
    }

    if (!status.nameMatchPassed &&
        status.bankVerified &&
        status.selfieVerified) {
      return AppRoutes.nameMatch;
    }

    return null;
  }

  static void goToNextKycStep(BuildContext context, KycFlowProvider kyc) {
    final auth = context.read<AuthProvider>();
    final next = nextIncompleteKycStep(kyc);
    if (next == null) {
      if (auth.isRegistrationFlow) {
        unawaited(RegistrationCompletion.finishAndGoHome(context));
      } else {
        context.go(AppRoutes.home);
      }
      return;
    }
    context.go(next);
  }

  /// Route for the step before [currentRoute] in the automated KYC flow.
  static String previousKycStep(KycFlowProvider kyc, {String? currentRoute}) {
    final current = currentRoute ?? nextIncompleteKycStep(kyc);
    return switch (current) {
      AppRoutes.nameMatch ||
      AppRoutes.selfieVerification ||
      AppRoutes.upiVerification ||
      AppRoutes.identityVerification =>
        AppRoutes.bankVerificationKyc,
      AppRoutes.bankVerificationKyc => AppRoutes.aadhaarVerificationKyc,
      AppRoutes.aadhaarVerificationKyc => AppRoutes.panVerification,
      AppRoutes.panVerification => AppRoutes.completeProfile,
      _ => AppRoutes.kycStatus,
    };
  }

  static void goToPreviousKycStep(
    BuildContext context,
    KycFlowProvider kyc, {
    String? currentRoute,
  }) {
    context.go(previousKycStep(kyc, currentRoute: currentRoute));
  }

  static String labelForPreviousKycStep(KycFlowProvider kyc, {String? currentRoute}) {
    final previous = previousKycStep(kyc, currentRoute: currentRoute);
    return switch (previous) {
      AppRoutes.panVerification => 'Back to PAN Verification',
      AppRoutes.aadhaarVerificationKyc => 'Back to Aadhaar Verification',
      AppRoutes.bankVerificationKyc => 'Back to Bank Verification',
      AppRoutes.identityVerification => 'Back to Identity Verification',
      AppRoutes.kycStatus => 'Back to KYC Status',
      _ => 'Back',
    };
  }

  static String labelForNextKycStep(KycFlowProvider kyc) {
    final next = nextIncompleteKycStep(kyc);
    return switch (next) {
      AppRoutes.panVerification => 'Continue to PAN Verification',
      AppRoutes.aadhaarVerificationKyc => 'Continue to Aadhaar Verification',
      AppRoutes.bankVerificationKyc => 'Continue to Bank Verification',
      AppRoutes.identityVerification ||
      AppRoutes.selfieVerification ||
      AppRoutes.upiVerification =>
        'Continue to UPI & Selfie Verification',
      AppRoutes.nameMatch => 'Continue to Name Match',
      _ => 'Continue to Home',
    };
  }
}
