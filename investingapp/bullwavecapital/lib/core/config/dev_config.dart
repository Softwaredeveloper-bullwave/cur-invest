import 'package:flutter/foundation.dart';

import '../constants/routes.dart';

/// Development shortcuts for UI work.
///
/// Set [skipToHomeForUiEditing] to `true` only when editing home UI without auth.
/// Normal flow: splash → onboarding → login → OTP → home.
class DevConfig {
  DevConfig._();

  /// Opens home immediately and bypasses auth + KYC gates (debug builds only).
  static const bool skipToHomeForUiEditing = false;

  /// After phone login + dev OTP, open bank verification for Eko testing (debug only).
  static const bool openBankVerificationAfterLogin = false;

  /// When [skipToHomeForUiEditing] is true, land on this route instead of home.
  static const String debugInitialRoute = AppRoutes.bankVerificationKyc;

  static bool get enabled => kDebugMode && skipToHomeForUiEditing;
}
