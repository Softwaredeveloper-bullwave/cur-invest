import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProvider extends ChangeNotifier {
  static const _onboardingKey = 'has_completed_app_onboarding';

  bool _isDarkMode = true;
  String _language = 'English';
  bool _isLoading = false;
  bool _hasCompletedOnboarding;

  AppProvider._({required bool hasCompletedOnboarding})
      : _hasCompletedOnboarding = hasCompletedOnboarding;

  static Future<AppProvider> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AppProvider._(
      hasCompletedOnboarding: prefs.getBool(_onboardingKey) ?? false,
    );
  }

  bool get isDarkMode => _isDarkMode;
  String get language => _language;
  bool get isLoading => _isLoading;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  void toggleDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  void setLanguage(String value) {
    _language = value;
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    if (_hasCompletedOnboarding) return;
    _hasCompletedOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
    notifyListeners();
  }
}
