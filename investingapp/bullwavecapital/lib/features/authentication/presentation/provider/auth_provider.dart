import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/config/dev_config.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/dev_auth_service.dart';
import '../../../../core/api/token_storage.dart';
import '../../../../core/storage/legal_consent_storage.dart';
import '../../../../models/user_model.dart';

enum AuthFlowMode { signIn, registration }

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
  bool _isNewUser = false;
  bool? _phoneIsRegistered;
  AuthFlowMode _flowMode = AuthFlowMode.signIn;
  String? _loginSuccessMessage;
  bool _hasSignedInSession = false;

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
  AuthFlowMode get flowMode => _flowMode;
  bool get isRegistrationFlow => _flowMode == AuthFlowMode.registration;
  bool get isSignInFlow => _flowMode == AuthFlowMode.signIn;
  String? get loginSuccessMessage => _loginSuccessMessage;
  bool get hasSignedInSession => _hasSignedInSession;

  /// True when splash may open Home without showing Login.
  bool get canAutoEnterApp =>
      _isAuthenticated && hasCompletedRegistration && _hasSignedInSession;

  /// Account was created on this sign-in (phone was not in the system before).
  bool get isNewUser => _isNewUser;

  /// Phone already had an account when OTP was sent (from send-otp API).
  bool get phoneIsRegistered => _phoneIsRegistered ?? false;

  /// Email + profile setup finished — user is past the registration funnel.
  bool get hasCompletedRegistration =>
      _isAuthenticated &&
      _user != null &&
      _user!.emailVerified &&
      _user!.hasCompletedOnboarding;

  /// Must complete email verification and/or profile before using the app.
  bool get needsRegistrationFlow =>
      _isAuthenticated && !hasCompletedRegistration;

  /// Returning user who already finished registration — should land on home.
  bool get isReturningRegisteredUser =>
      _isAuthenticated && hasCompletedRegistration && !_isNewUser;

  bool get needsEmailVerification =>
      needsRegistrationFlow && (_user?.emailVerified != true);

  bool get needsEmailOtpEntry =>
      needsEmailVerification && _pendingEmail.isNotEmpty;

  bool get needsProfileSetup =>
      _isAuthenticated &&
      _user?.emailVerified == true &&
      (_user?.hasCompletedOnboarding != true);

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

  void beginRegistration() {
    _flowMode = AuthFlowMode.registration;
    _loginSuccessMessage = null;
    unawaited(TokenStorage.setRegistrationInProgress(true));
    notifyListeners();
  }

  void endRegistration() {
    _flowMode = AuthFlowMode.signIn;
    unawaited(TokenStorage.setRegistrationInProgress(false));
    notifyListeners();
  }

  void beginSignIn() {
    _flowMode = AuthFlowMode.signIn;
    notifyListeners();
  }

  void setLoginSuccessMessage(String? message) {
    _loginSuccessMessage = message;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> markSignedInSession() async {
    _hasSignedInSession = true;
    await TokenStorage.setSignedInSession(true);
    notifyListeners();
  }

  Future<void> _loadSessionFlags() async {
    _hasSignedInSession = await TokenStorage.hasSignedInSession();
    if (await TokenStorage.isRegistrationInProgress()) {
      _flowMode = AuthFlowMode.registration;
    }
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
    _user =
        user ??
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

  Future<void> prepareForLoginScreen() async {
    if (DevConfig.enabled) {
      await _bootstrapDevSession();
      return;
    }
    await _api.init();
    await _loadSessionFlags();
    beginSignIn();
    _isAuthenticated = false;
    _user = null;
    _phoneNumber = '';
    _pendingEmail = '';
    _isNewUser = false;
    _phoneIsRegistered = null;
    _hasSignedInSession = false;
    await TokenStorage.setSignedInSession(false);
    _termsAccepted = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<bool> tryRestoreSession() async {
    if (DevConfig.enabled) {
      await _bootstrapDevSession();
      return true;
    }

    await _api.init();
    await _loadSessionFlags();
    _pendingEmail = await TokenStorage.getPendingEmail() ?? '';
    final accessToken = await TokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      _isAuthenticated = false;
      _user = null;
      notifyListeners();
      return false;
    }

    try {
      _user = await _api.getProfile();
      _isAuthenticated = true;
      _isNewUser = false;
      if (_user?.emailVerified == true) {
        _pendingEmail = '';
        await TokenStorage.savePendingEmail('');
      } else if (_pendingEmail.isEmpty && (_user?.email.isNotEmpty ?? false)) {
        _pendingEmail = _user!.email.trim().toLowerCase();
      }

      // Only clear a completed registration token when registration is not active.
      if (!_hasSignedInSession && hasCompletedRegistration) {
        final regInProgress = await TokenStorage.isRegistrationInProgress();
        if (!regInProgress) {
          await TokenStorage.setRegistrationInProgress(false);
          _flowMode = AuthFlowMode.signIn;
          await logout();
          return false;
        }
      }

      notifyListeners();
      return _isAuthenticated;
    } catch (_) {
      final refreshed = await _api.refreshAccessToken();
      if (refreshed) {
        try {
          _user = await _api.getProfile();
          _isAuthenticated = true;
          _isNewUser = false;
          notifyListeners();
          return true;
        } catch (_) {}
      }
      await logout();
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
      _phoneIsRegistered = result.isRegistered;
      if (_flowMode == AuthFlowMode.signIn && !result.isRegistered) {
        beginRegistration();
      }
      await LegalConsentStorage.recordTermsAcceptance();
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
      final result = await _api.verifyOtp(_phoneNumber, code);
      _user = result.user;
      _isNewUser = result.isNewUser;
      _isAuthenticated = true;
      await AppLockService.clearIfDifferentUser(_user?.id ?? '');
      await _syncPendingEmailState();

      if (_flowMode == AuthFlowMode.signIn) {
        if (hasCompletedRegistration) {
          await markSignedInSession();
          await TokenStorage.setRegistrationInProgress(false);
          _flowMode = AuthFlowMode.signIn;
        } else {
          beginRegistration();
          _hasSignedInSession = false;
          await TokenStorage.setSignedInSession(false);
          await TokenStorage.setRegistrationInProgress(true);
        }
      } else if (_flowMode == AuthFlowMode.registration) {
        await TokenStorage.setSignedInSession(false);
        _hasSignedInSession = false;
        await TokenStorage.setRegistrationInProgress(true);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      _isAuthenticated = false;
      await _api.logout();
      notifyListeners();
      return false;
    } catch (e) {
      _error = e is TimeoutException
          ? 'Server took too long. Check Django is running and try again.'
          : 'Could not verify OTP. Check your connection.';
      _isLoading = false;
      _isAuthenticated = false;
      await _api.logout();
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
      _user =
          result.user ??
          _user?.copyWith(email: normalized, emailVerified: false);
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
      if (_flowMode == AuthFlowMode.registration) {
        await TokenStorage.setRegistrationInProgress(true);
        _hasSignedInSession = false;
        await TokenStorage.setSignedInSession(false);
      }
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
    _isNewUser = false;
    _phoneIsRegistered = null;
    _flowMode = AuthFlowMode.signIn;
    _hasSignedInSession = false;
    await TokenStorage.setSignedInSession(false);
    await TokenStorage.setRegistrationInProgress(false);
    _termsAccepted = false;
    notifyListeners();
  }
}
