import 'package:shared_preferences/shared_preferences.dart';

import '../constants/legal_config.dart';

/// Local persistence for legal consent — no backend API changes required.
class LegalConsentStorage {
  LegalConsentStorage._();

  static const _termsAcceptedKey = 'legal_terms_accepted';
  static const _termsAcceptedAtKey = 'legal_terms_accepted_at';
  static const _termsAppVersionKey = 'legal_terms_app_version';
  static const _privacyAckKey = 'legal_privacy_acknowledged';
  static const _kycConsentKey = 'legal_kyc_consent_given';
  static const _investmentRiskKey = 'legal_investment_risk_ack';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> recordTermsAcceptance() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_termsAcceptedKey, true);
    await prefs.setBool(_privacyAckKey, true);
    await prefs.setString(
      _termsAcceptedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    await prefs.setString(_termsAppVersionKey, LegalConfig.appVersionLabel);
  }

  static Future<bool> hasAcceptedTerms() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_termsAcceptedKey) ?? false;
  }

  static Future<bool> hasAcknowledgedPrivacy() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_privacyAckKey) ?? false;
  }

  static Future<void> setKycConsent(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_kycConsentKey, value);
  }

  static Future<bool> hasKycConsent() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_kycConsentKey) ?? false;
  }

  static Future<void> setInvestmentRiskAcknowledged(bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_investmentRiskKey, value);
  }

  static Future<bool> hasInvestmentRiskAcknowledged() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_investmentRiskKey) ?? false;
  }
}
