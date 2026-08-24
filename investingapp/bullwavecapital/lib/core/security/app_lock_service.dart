import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Device-local MPIN + biometric preferences. No backend API.
class AppLockService {
  AppLockService._();

  static const _storage = FlutterSecureStorage();

  static const _mpinHashKey = 'app_lock_mpin_hash';
  static const _mpinSaltKey = 'app_lock_mpin_salt';
  static const _userIdKey = 'app_lock_user_id';
  static const _enabledKey = 'app_lock_enabled';
  static const _biometricKey = 'app_lock_biometric';

  static const pinLength = 4;
  static const maxAttempts = 5;

  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Human-readable labels for UI (fingerprint vs face vs generic).
  static Future<List<BiometricType>> availableBiometricTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> isBiometricAvailable() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return false;
      if (await _localAuth.canCheckBiometrics) return true;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e) {
      debugPrint('AppLockService.isBiometricAvailable: $e');
      return false;
    }
  }

  static String biometricLabel(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face unlock';
    }
    if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    }
    if (types.contains(BiometricType.strong) ||
        types.contains(BiometricType.weak)) {
      return 'Biometric unlock';
    }
    return 'Fingerprint / Face unlock';
  }

  static Future<bool> authenticateWithBiometric() async {
    const reason = 'Unlock Capital BullWave';

    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        ),
      );
    } on PlatformException catch (e) {
      if (_isUserCanceledPlatformError(e)) return false;
      debugPrint(
        'AppLockService.authenticate: ${e.code} ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('AppLockService.authenticate: $e');
      return false;
    }
  }

  static bool _isUserCanceledPlatformError(PlatformException e) {
    const canceledCodes = {
      'UserCancel',
      'Canceled',
      'auth_in_progress',
      'UserCanceled',
    };
    return canceledCodes.contains(e.code);
  }

  static Future<bool> hasMpin() async {
    final hash = await _storage.read(key: _mpinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  static Future<bool> isEnabled() async {
    if (!await hasMpin()) return false;
    final value = await _storage.read(key: _enabledKey);
    return value != 'false';
  }

  static Future<bool> isBiometricEnabled() async {
    if (!await isEnabled()) return false;
    final value = await _storage.read(key: _biometricKey);
    return value == 'true';
  }

  static Future<String?> boundUserId() => _storage.read(key: _userIdKey);

  static Future<bool> isBoundToUser(String userId) async {
    if (userId.isEmpty) return false;
    final bound = await boundUserId();
    return bound != null && bound == userId;
  }

  static Future<void> setupMpin({
    required String pin,
    required String userId,
    bool enableBiometric = false,
  }) async {
    _validatePin(pin);
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _mpinSaltKey, value: salt);
    await _storage.write(key: _mpinHashKey, value: hash);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _enabledKey, value: 'true');
    await _storage.write(
      key: _biometricKey,
      value: enableBiometric ? 'true' : 'false',
    );
  }

  static Future<bool> verifyMpin(String pin) async {
    _validatePin(pin);
    final salt = await _storage.read(key: _mpinSaltKey);
    final storedHash = await _storage.read(key: _mpinHashKey);
    if (salt == null || storedHash == null) return false;
    return storedHash == _hashPin(pin, salt);
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricKey,
      value: enabled ? 'true' : 'false',
    );
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!enabled) {
      await clearAll();
      return;
    }
    await _storage.write(key: _enabledKey, value: 'true');
  }

  static Future<void> changeMpin({
    required String currentPin,
    required String newPin,
  }) async {
    final ok = await verifyMpin(currentPin);
    if (!ok) {
      throw AppLockException('Current MPIN is incorrect.');
    }
    final userId = await boundUserId();
    if (userId == null || userId.isEmpty) {
      throw AppLockException('MPIN is not configured.');
    }
    final biometric = await isBiometricEnabled();
    await setupMpin(
      pin: newPin,
      userId: userId,
      enableBiometric: biometric,
    );
  }

  /// Clear MPIN when a different user signs in on this device.
  static Future<void> clearIfDifferentUser(String userId) async {
    if (userId.isEmpty) return;
    final bound = await boundUserId();
    if (bound != null && bound.isNotEmpty && bound != userId) {
      await clearAll();
    }
  }

  static Future<void> clearAll() async {
    await _storage.delete(key: _mpinHashKey);
    await _storage.delete(key: _mpinSaltKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _biometricKey);
  }

  static String _hashPin(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$salt:$pin')).toString();
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(utf8.encode('$digest:$salt')).toString();
    }
    return digest;
  }

  static String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static void _validatePin(String pin) {
    final digits = pin.replaceAll(RegExp(r'\D'), '');
    if (digits.length != pinLength) {
      throw AppLockException('MPIN must be $pinLength digits.');
    }
  }

  /// Visible for unit tests only.
  static String hashPinForTest(String pin, String salt) => _hashPin(pin, salt);
}

class AppLockException implements Exception {
  AppLockException(this.message);
  final String message;

  @override
  String toString() => message;
}
