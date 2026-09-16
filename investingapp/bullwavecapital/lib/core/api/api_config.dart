import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Django backend base URL.
///
/// **Override at build time:**
/// ```bash
/// flutter run -d chrome --dart-define=API_BASE_URL=http://43.204.159.255/api/v1
/// ```
///
/// **Host-only override (HTTP on port 80):**
/// `flutter run --dart-define=API_HOST=43.204.159.255`
class ApiConfig {
  ApiConfig._();

  /// Default backend when no `--dart-define=API_BASE_URL` is passed.
  /// Current AWS Elastic IP (HTTP :80) until api.capitalbullwave.com TLS is back.
  static const String defaultApiBaseUrl = 'http://43.204.159.255/api/v1';

  static const String _apiBaseFromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String _apiHostFromEnv = String.fromEnvironment(
    'API_HOST',
    defaultValue: '',
  );

  /// Set to override [defaultApiBaseUrl] without a build flag (host only, port 80).
  static const String? hostOverride = null;

  static String get baseUrl {
    final fromEnv = _normalizeBase(_apiBaseFromEnv.trim());
    if (fromEnv.isNotEmpty) return fromEnv;

    final hostFromDefine = _apiHostFromEnv.trim();
    if (hostFromDefine.isNotEmpty) {
      return _normalizeBase('http://$hostFromDefine/api/v1');
    }

    if (hostOverride != null && hostOverride!.isNotEmpty) {
      return _normalizeBase('http://$hostOverride/api/v1');
    }

    if (kReleaseMode) {
      return _normalizeBase(AppEnv.productionApiBaseUrl);
    }

    return _normalizeBase(defaultApiBaseUrl);
  }

  static String get _apiHost {
    final fromEnv = _apiBaseFromEnv.trim();
    if (fromEnv.isNotEmpty) {
      return Uri.parse(fromEnv).host;
    }
    final hostFromDefine = _apiHostFromEnv.trim();
    if (hostFromDefine.isNotEmpty) {
      return hostFromDefine;
    }
    if (hostOverride != null && hostOverride!.isNotEmpty) {
      return hostOverride!;
    }
    if (kReleaseMode) {
      return Uri.parse(AppEnv.productionApiBaseUrl).host;
    }
    return Uri.parse(defaultApiBaseUrl).host;
  }

  static bool get isProductionApi =>
      baseUrl.startsWith('https://') && kReleaseMode;

  /// Rewrites Django media URLs so images load on emulator / physical device.
  static String resolveMediaUrl(String url) {
    if (url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    return uri.replace(host: _apiHost).toString();
  }

  static String _normalizeBase(String url) {
    if (url.isEmpty) return url;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
