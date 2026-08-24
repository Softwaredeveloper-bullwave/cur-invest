import 'package:flutter/foundation.dart';

import 'package:local_auth/local_auth.dart';

import 'app_lock_service.dart';

class AppLockProvider extends ChangeNotifier {
  bool _initialized = false;
  bool _isUnlocked = false;
  bool _hasMpin = false;
  bool _isEnabled = false;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  List<BiometricType> _biometricTypes = const [];
  int _failedAttempts = 0;
  String? _error;

  bool get initialized => _initialized;
  bool get isUnlocked => _isUnlocked;
  bool get hasMpin => _hasMpin;
  bool get isEnabled => _isEnabled;
  bool get biometricEnabled => _biometricEnabled;
  bool get biometricAvailable => _biometricAvailable;
  List<BiometricType> get biometricTypes => _biometricTypes;
  String get biometricLabel => AppLockService.biometricLabel(_biometricTypes);
  int get failedAttempts => _failedAttempts;
  int get attemptsRemaining => AppLockService.maxAttempts - _failedAttempts;
  String? get error => _error;

  bool get requiresUnlock => _isEnabled && _hasMpin && !_isUnlocked;

  Future<void> refreshBiometricAvailability() async {
    _biometricAvailable = await AppLockService.isBiometricAvailable();
    _biometricTypes = await AppLockService.availableBiometricTypes();
    notifyListeners();
  }

  Future<void> init({String? userId}) async {
    _failedAttempts = 0;
    await refreshBiometricAvailability();
    _hasMpin = await AppLockService.hasMpin();
    _isEnabled = await AppLockService.isEnabled();
    _biometricEnabled = await AppLockService.isBiometricEnabled();

    if (userId != null && userId.isNotEmpty) {
      await AppLockService.clearIfDifferentUser(userId);
      if (!await AppLockService.isBoundToUser(userId)) {
        _hasMpin = false;
        _isEnabled = false;
        _biometricEnabled = false;
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> refresh() async {
    _hasMpin = await AppLockService.hasMpin();
    _isEnabled = await AppLockService.isEnabled();
    _biometricEnabled = await AppLockService.isBiometricEnabled();
    notifyListeners();
  }

  void markUnlocked() {
    _isUnlocked = true;
    _failedAttempts = 0;
    _error = null;
    notifyListeners();
  }

  void lock() {
    if (!_isEnabled || !_hasMpin) return;
    _isUnlocked = false;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<bool> setupMpin({
    required String pin,
    required String userId,
    bool enableBiometric = false,
  }) async {
    try {
      await refreshBiometricAvailability();
      var useBiometric = enableBiometric && _biometricAvailable;
      if (useBiometric) {
        useBiometric = await AppLockService.authenticateWithBiometric();
      }
      await AppLockService.setupMpin(
        pin: pin,
        userId: userId,
        enableBiometric: useBiometric,
      );
      await refresh();
      markUnlocked();
      return true;
    } on AppLockException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyMpin(String pin) async {
    _error = null;
    final ok = await AppLockService.verifyMpin(pin);
    if (ok) {
      markUnlocked();
      return true;
    }

    _failedAttempts += 1;
    if (_failedAttempts >= AppLockService.maxAttempts) {
      _error = 'Too many attempts. Please sign in with your phone number.';
    } else {
      _error = 'Incorrect MPIN. $attemptsRemaining attempt(s) left.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> unlockWithBiometric() async {
    if (!_biometricEnabled || !_biometricAvailable) return false;
    _error = null;
    final ok = await AppLockService.authenticateWithBiometric();
    if (ok) {
      markUnlocked();
      return true;
    }
    _error = 'Biometric authentication failed. Try your MPIN.';
    notifyListeners();
    return false;
  }

  Future<bool> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await refreshBiometricAvailability();
      if (!_biometricAvailable) {
        _error =
            'Biometrics not available. Enroll fingerprint or face unlock in phone Settings.';
        notifyListeners();
        return false;
      }
      final verified = await AppLockService.authenticateWithBiometric();
      if (!verified) {
        _error = 'Biometric verification cancelled or failed.';
        notifyListeners();
        return false;
      }
    }

    await AppLockService.setBiometricEnabled(enabled);
    _biometricEnabled = enabled;
    _error = null;
    notifyListeners();
    return true;
  }

  Future<void> disableAppLock() async {
    await AppLockService.clearAll();
    _hasMpin = false;
    _isEnabled = false;
    _biometricEnabled = false;
    _isUnlocked = false;
    _failedAttempts = 0;
    _error = null;
    notifyListeners();
  }

  Future<bool> changeMpin({
    required String currentPin,
    required String newPin,
  }) async {
    try {
      await AppLockService.changeMpin(
        currentPin: currentPin,
        newPin: newPin,
      );
      _error = null;
      notifyListeners();
      return true;
    } on AppLockException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  bool shouldForceLogout() =>
      _failedAttempts >= AppLockService.maxAttempts;
}
