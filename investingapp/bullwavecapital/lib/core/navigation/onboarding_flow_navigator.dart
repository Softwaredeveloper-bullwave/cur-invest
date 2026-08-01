import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/routes.dart';
import '../../features/authentication/presentation/provider/auth_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';

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
    if (auth.needsEmailVerification) {
      return auth.needsEmailOtpEntry
          ? AppRoutes.verifyEmailOtp
          : AppRoutes.verifyEmail;
    }
    if (auth.needsProfileSetup) return AppRoutes.completeProfile;
    return routeAfterProfileComplete(kyc);
  }

  static String routeAfterProfileComplete(KycFlowProvider kyc) {
    if (!kyc.usesAutomatedKyc) return kyc.verificationRoute;
    return nextIncompleteKycStep(kyc) ?? AppRoutes.home;
  }

  /// First incomplete automated KYC step, or null when fully verified.
  static String? nextIncompleteKycStep(KycFlowProvider kyc) {
    final status = kyc.status;
    if (!status.panVerified) return AppRoutes.panVerification;
    if (!status.aadhaarVerified) return AppRoutes.aadhaarVerificationKyc;
    if (!status.canProceedToIdentity) return AppRoutes.bankVerificationKyc;

    final useCombinedIdentity = status.upiManual || kyc.upiRequired;
    if (useCombinedIdentity) {
      final identityDone = status.upiVerified && status.selfieVerified;
      final awaitingAdmin = status.identityReviewPending ||
          status.selfieReviewPending ||
          (status.manualFinalApprovalRequired && !status.finalKycApproved);
      if (!identityDone || awaitingAdmin) {
        return AppRoutes.identityVerification;
      }
    } else {
      if (!status.selfieVerified) return AppRoutes.selfieVerification;
    }

    if (status.manualFinalApprovalRequired) {
      if (!status.finalKycApproved) return AppRoutes.identityVerification;
      return null;
    }
    if (!status.nameMatchPassed) return AppRoutes.nameMatch;
    return null;
  }

  static void goToNextKycStep(BuildContext context, KycFlowProvider kyc) {
    context.go(nextIncompleteKycStep(kyc) ?? AppRoutes.home);
  }

  /// Route for the step before [currentRoute] in the automated KYC flow.
  static String previousKycStep(KycFlowProvider kyc, {String? currentRoute}) {
    final current = currentRoute ?? nextIncompleteKycStep(kyc);
    return switch (current) {
      AppRoutes.identityVerification ||
      AppRoutes.selfieVerification ||
      AppRoutes.upiVerification =>
        AppRoutes.bankVerificationKyc,
      AppRoutes.nameMatch => AppRoutes.identityVerification,
      AppRoutes.bankVerificationKyc => AppRoutes.aadhaarVerificationKyc,
      AppRoutes.aadhaarVerificationKyc => AppRoutes.panVerification,
      AppRoutes.panVerification => AppRoutes.kycStatus,
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
      AppRoutes.selfieVerification => 'Continue to Selfie Verification',
      AppRoutes.identityVerification => 'Continue to Identity Verification',
      AppRoutes.upiVerification => 'Continue to UPI Verification',
      AppRoutes.nameMatch => 'Continue to Name Match',
      _ => 'Continue to Home',
    };
  }
}
