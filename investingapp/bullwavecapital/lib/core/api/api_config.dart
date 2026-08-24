import 'package:flutter/foundation.dart';

import '../config/app_env.dart';

/// Django backend base URL.
///
/// **Override at build time:**
/// ```bash
/// flutter run --dart-define=API_BASE_URL=https://api.capitalbullwave.com/api/v1
/// ```
///
/// **Legacy host override (no port — nginx serves on 80):**
/// `flutter run --dart-define=API_HOST=54.252.109.12`
class ApiConfig {
  ApiConfig._();

  /// Default backend when no `--dart-define=API_BASE_URL` is passed.
  /// Use HTTPS — nginx on EC2 redirects HTTP → 301, which breaks Dio POST requests.
  static const String defaultApiBaseUrl =
      'https://api.capitalbullwave.com/api/v1';

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
      return _normalizeBase('https://$hostFromDefine/api/v1');
    }

    if (hostOverride != null && hostOverride!.isNotEmpty) {
      return _normalizeBase('https://$hostOverride/api/v1');
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
