import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/dev_auth_service.dart';
import '../../../../core/api/token_storage.dart';
import '../../../../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  AuthProvider() {
    if (DevConfig.enabled) {
      unawaited(_bootstrapDevSession());
    }
  }

  String _phoneNumber = '';
  bool _termsAccepted = false;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  UserModel? _user;
  String? _error;
  String? _devOtp;
  String _otpMode = 'console';
  String _pendingEmail = '';
  String _emailOtpMode = 'email';

  String get phoneNumber => _phoneNumber;
  String get pendingEmail => _pendingEmail;
  bool get termsAccepted => _termsAccepted;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  UserModel? get user => _user;
  String? get error => _error;
  String? get devOtp => AppEnv.showDevOtpHints ? _devOtp : null;
  bool get otpIsConsoleMode => _otpMode == 'console';
  bool get emailOtpIsConsoleMode => _emailOtpMode == 'console';

  bool get needsEmailVerification =>
      _isAuthenticated && (_user?.emailVerified != true);

  bool get needsEmailOtpEntry =>
      needsEmailVerification && _pendingEmail.isNotEmpty;

  bool get needsProfileSetup =>
      _isAuthenticated && _user?.emailVerified == true && (_user?.hasCompletedOnboarding != true);

  void setPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    _phoneNumber = digits.length >= 10 ? digits.substring(0, 10) : digits;
  }

  void setTermsAccepted(bool value) {
    _termsAccepted = value;
    notifyListeners();
  }

  Future<void> _syncPendingEmailState() async {
    _pendingEmail = await TokenStorage.getPendingEmail() ?? '';
    if (_user?.emailVerified == true) {
      _pendingEmail = '';
      await TokenStorage.savePendingEmail('');
      return;
    }
    if (_pendingEmail.isEmpty && (_user?.email.isNotEmpty ?? false)) {
      _pendingEmail = _user!.email.trim().toLowerCase();
    }
  }

  void _applyDevSession({UserModel? user}) {
    _isAuthenticated = true;
    _user = user ??
        const UserModel(
          id: 'dev-user',
          name: 'Dev User',
          phone: '9999999999',
          email: 'dev@bullwave.local',
          panStatus: 'Verified',
          kycStatus: 'verified',
          avatarUrl: '',
          hasCompletedOnboarding: true,
          emailVerified: true,
        );
    notifyListeners();
  }

  Future<void> _bootstrapDevSession() async {
    _applyDevSession();
    final ok = await DevAuthService.ensureSession(_api);
    if (ok) {
      try {
        _user = await _api.getProfile();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> tryRestoreSession() async {
    if (DevConfig.enabled) {
      await _bootstrapDevSession();
      return true;
    }

    await _api.init();
    _pendingEmail = await TokenStorage.getPendingEmail() ?? '';
    try {
      _user = await _api.getProfile();
      _isAuthenticated = true;
      if (_user?.emailVerified == true) {
        _pendingEmail = '';
        await TokenStorage.savePendingEmail('');
      } else if (_pendingEmail.isEmpty && (_user?.email.isNotEmpty ?? false)) {
        _pendingEmail = _user!.email.trim().toLowerCase();
      }
      notifyListeners();
      return true;
    } catch (_) {
      _isAuthenticated = false;
      _user = null;
      _pendingEmail = '';
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendOtp() async {
    if (_phoneNumber.length != 10 || !_termsAccepted) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.sendOtp(_phoneNumber);
      if (AppEnv.blockConsoleOtpInRelease && result.isConsoleMode) {
        _error =
            'Login is temporarily unavailable. Please try again in a few minutes.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _devOtp = result.devOtp;
      _otpMode = result.otpMode;
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = AppEnv.isRelease
          ? 'Cannot reach the server. Check your internet connection and try again.'
          : 'Cannot reach server at ${ApiConfig.baseUrl}. Check Wi‑Fi/VPN, then restart the app (full rebuild on macOS: stop flutter run and start again). (${e.runtimeType})';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _phoneNumber.length != 10) {
      _error = _phoneNumber.length != 10
          ? 'Phone number missing. Go back and enter your number again.'
          : 'Enter all 6 digits.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.verifyOtp(_phoneNumber, code);
      _isAuthenticated = true;
      await _syncPendingEmailState();
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e is TimeoutException
          ? 'Server took too long. Check Django is running and try again.'
          : 'Could not verify OTP. Check your connection.';
      _isLoading = false;
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshProfile() async {
    try {
      _user = await _api.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> sendEmailOtp(String email) async {
    final normalized = email.trim().toLowerCase();
    if (!normalized.contains('@')) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.sendEmailOtp(normalized);
      _pendingEmail = normalized;
      await TokenStorage.savePendingEmail(normalized);
      _devOtp = result.devOtp;
      _emailOtpMode = result.otpMode;
      _user = result.user ?? _user?.copyWith(email: normalized, emailVerified: false);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Could not send email verification code. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmailOtp(String otp) async {
    final code = otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || _pendingEmail.isEmpty) {
      _error = _pendingEmail.isEmpty
          ? 'Enter your email again to receive a verification code.'
          : 'Enter all 6 digits.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.verifyEmailOtp(_pendingEmail, code);
      _pendingEmail = '';
      await TokenStorage.savePendingEmail('');
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Could not verify email code. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> completeProfileSetup({
    required String name,
    required String email,
    required String city,
    String bio = '',
    DateTime? dateOfBirth,
    String referralCode = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.completeProfileSetup(
        name: name.trim(),
        email: email.trim(),
        city: city.trim(),
        bio: bio.trim(),
        dateOfBirth: dateOfBirth,
        referralCode: referralCode.trim(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to save profile. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String email,
    required String city,
    required String bio,
    DateTime? dateOfBirth,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.updateProfile(
        name: name.trim(),
        email: email.trim(),
        city: city.trim(),
        bio: bio.trim(),
        dateOfBirth: dateOfBirth,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to save profile.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadAvatar(List<int> bytes, String filename) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _api.uploadAvatar(bytes, filename);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to upload photo.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeAvatar() async {
    try {
      _user = await _api.removeAvatar();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    _isAuthenticated = false;
    _user = null;
    _phoneNumber = '';
    _pendingEmail = '';
    await TokenStorage.savePendingEmail('');
    _termsAccepted = false;
    notifyListeners();
  }
}
