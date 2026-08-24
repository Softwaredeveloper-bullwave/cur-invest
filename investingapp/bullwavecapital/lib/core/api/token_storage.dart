import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// JWT + session flags. Tokens live in encrypted storage when available.
class TokenStorage {
  TokenStorage._();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _pendingEmailKey = 'pending_email_verification';
  static const _signedInSessionKey = 'signed_in_session';
  static const _registrationInProgressKey = 'registration_in_progress';
  static const _migrationDoneKey = 'secure_token_migration_done';

  static const _secure = FlutterSecureStorage();

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _migrateTokensToSecureStorage();
  }

  static Future<void> _migrateTokensToSecureStorage() async {
    if (_prefs!.getBool(_migrationDoneKey) == true) return;

    final legacyAccess = _prefs!.getString(_accessKey);
    final legacyRefresh = _prefs!.getString(_refreshKey);
    if (legacyAccess != null && legacyAccess.isNotEmpty) {
      await _secure.write(key: _accessKey, value: legacyAccess);
      await _prefs!.remove(_accessKey);
    }
    if (legacyRefresh != null && legacyRefresh.isNotEmpty) {
      await _secure.write(key: _refreshKey, value: legacyRefresh);
      await _prefs!.remove(_refreshKey);
    }
    await _prefs!.setBool(_migrationDoneKey, true);
  }

  static Future<void> saveTokens({
    required String access,
    required String refresh,
  }) async {
    await init();
    await _secure.write(key: _accessKey, value: access);
    await _secure.write(key: _refreshKey, value: refresh);
  }

  static Future<String?> getAccessToken() async {
    await init();
    return _secure.read(key: _accessKey);
  }

  static Future<String?> getRefreshToken() async {
    await init();
    return _secure.read(key: _refreshKey);
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

  /// True only after the user completes Sign in on the Login screen (not registration OTP).
  static Future<bool> hasSignedInSession() async {
    await init();
    return _prefs!.getBool(_signedInSessionKey) ?? false;
  }

  static Future<void> setSignedInSession(bool value) async {
    await init();
    await _prefs!.setBool(_signedInSessionKey, value);
  }

  static Future<bool> isRegistrationInProgress() async {
    await init();
    return _prefs!.getBool(_registrationInProgressKey) ?? false;
  }

  static Future<void> setRegistrationInProgress(bool value) async {
    await init();
    await _prefs!.setBool(_registrationInProgressKey, value);
  }

  static Future<void> clear() async {
    await init();
    await _secure.delete(key: _accessKey);
    await _secure.delete(key: _refreshKey);
    await _prefs!.remove(_pendingEmailKey);
    await _prefs!.remove(_signedInSessionKey);
    await _prefs!.remove(_registrationInProgressKey);
  }
}
