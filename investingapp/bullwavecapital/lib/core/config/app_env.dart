import 'package:flutter/foundation.dart';

/// Build-time and runtime environment helpers for dev vs Play Store release.
class AppEnv {
  AppEnv._();

  /// `true` for Play Store / profile / release builds.
  static bool get isRelease => kReleaseMode;

  /// Dev UI shortcuts (skip auth, auto-login). Never enabled in release.
  static bool get allowsDevShortcuts => kDebugMode;

  /// Default production API when `--dart-define=API_BASE_URL=...` is omitted.
  static const String productionApiBaseUrl = 'https://api.capitalbullwave.com/api/v1';

  /// Whether OTP console/dev hints may be shown in the UI (debug + profile builds).
  static bool get showDevOtpHints => !kReleaseMode;

  /// Block login when backend returns console OTP mode (SMS not configured).
  static bool get blockConsoleOtpInRelease => kReleaseMode;
}
