import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _pendingEmailKey = 'pending_email_verification';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await init();
    await _prefs!.setString(_accessKey, access);
    await _prefs!.setString(_refreshKey, refresh);
  }

  static Future<String?> getAccessToken() async {
    await init();
    return _prefs!.getString(_accessKey);
  }

  static Future<void> savePendingEmail(String email) async {
    await init();
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      await _prefs!.remove(_pendingEmailKey);
      return;
    }
    await _prefs!.setString(_pendingEmailKey, normalized);
  }

  static Future<String?> getPendingEmail() async {
    await init();
    return _prefs!.getString(_pendingEmailKey);
  }

  static Future<void> clear() async {
    await init();
    await _prefs!.remove(_accessKey);
    await _prefs!.remove(_refreshKey);
    await _prefs!.remove(_pendingEmailKey);
  }
}
