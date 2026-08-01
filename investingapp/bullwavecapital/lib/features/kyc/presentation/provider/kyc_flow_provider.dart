import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/dev_config.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/constants/routes.dart';

import '../../data/kyc_repository.dart';

import '../../domain/kyc_models.dart';

import '../../models/kyc_status_model.dart';

import '../../services/kyc_api_service.dart';

class KycFlowProvider extends ChangeNotifier {
  final _kycRepo = KycRepository();

  final _manualApi = KycApiService.instance;

  final _paymentRepo = PaymentRepository();

  KycStatusModel status = KycStatusModel.empty;

  ManualKycStatusModel manualStatus = ManualKycStatusModel.empty;

  bool isLoading = false;

  bool statusLoaded = false;

  String? error;

  /// Called after verified KYC steps so profile UI picks up the legal name.
  Future<void> Function()? onIdentityUpdated;

  Future<void> _notifyIdentityUpdated() async {
    final callback = onIdentityUpdated;
    if (callback != null) {
      await callback();
    }
  }

  bool get isManualKycVerified => manualStatus.isVerified;

  /// Automated step flow (Eko/Cashfree per-step), not legacy document upload.
  bool get usesAutomatedKyc => status.usesAutomatedKyc;

  /// Backward-compatible alias — true when legacy provider flag is eko.
  bool get usesEko => status.provider.toLowerCase() == 'eko';

  bool get upiRequired => status.upiRequired;

  String get verificationRoute {
    if (usesAutomatedKyc || status.panVerified) {
      return AppRoutes.kycStatus;
    }
    return AppRoutes.kycSubmit;
  }

  /// Markets & trading access.
  bool get isFullyVerified =>
      DevConfig.enabled ||
      (usesAutomatedKyc ? status.isFullyVerified : isManualKycVerified);

  void reset() {
    status = KycStatusModel.empty;

    manualStatus = ManualKycStatusModel.empty;

    isLoading = false;

    statusLoaded = false;

    error = null;

    notifyListeners();
  }

  String _messageFromError(Object error, String fallback) {
    if (error is ApiException) {
      if (error.isFraud) {
        return 'Verification blocked for security. Wait a few minutes and use the correct details.';
      }
      if (error.isIpBlocked) {
        return 'Cashfree blocked this server IP. Add your IP in Cashfree Secure ID → Settings → IP Whitelist, then restart Django and retry.';
      }
      if (error.code == 'invalid_account_fail' ||
          error.code == 'invalid_ifsc_fail') {
        return 'Invalid bank account or IFSC. Check the details and retry.';
      }
      if (error.code == 'failed_at_bank') {
        return error.message.contains('sandbox')
            ? error.message
            : 'Cashfree could not verify this bank account. Check account number and IFSC.';
      }
      if (error.code == 'upi_service_unavailable' || error.code == 'upi_unavailable' || error.code == 'eko_route_not_found') {
        return error.message;
      }
      if (error.code == 'upi_invalid') {
        return 'This UPI ID is invalid or inactive. Check the VPA and try again.';
      }
      if (error.code == 'upi_name_missing') {
        return 'Eko could not fetch the payee name for this UPI ID. Try another UPI ID or contact support.';
      }
      return error.message;
    }

    if (error is DioException && error.error is ApiException) {
      return _messageFromError(error.error as ApiException, fallback);
    }

    return fallback;
  }

  String _digilockerApiError(ApiException e) {
    if (e.code == 'session_expired') {
      return 'DigiLocker session expired. Tap “Start a new verification” and complete consent again.';
    }
    if (e.code == 'public_redirect_required') {
      return 'DigiLocker needs HTTPS. In backend/.env set LOCAL_DEV_TUNNEL_URL to your '
          'localtunnel URL (run: npx localtunnel --port 8000), then restart Django.';
    }
    return e.message;
  }

  /// Primary status load
  /// refreshes the real per-step Eko status (PAN/Aadhaar/Bank/Name-match) so
  /// screens don't ask the user to re-verify something already stored in the
  /// database after an app restart or navigating away and back.

  Future<void> loadStatus() async {
    await loadManualStatus();

    await loadKycStatus();
  }

  /// Refreshes `status` (panVerified/aadhaarVerified/bankVerified/etc.) from
  /// GET /kyc-status/ — the source of truth already saved in the database.
  /// Call this on screen entry for PAN/Aadhaar/Bank verification screens so
  /// they show the "already verified" state instead of a blank form when the
  /// backend already has it verified.

  Future<void> loadKycStatus() async {
    try {
      status = await _kycRepo.fetchStatus();

      notifyListeners();
    } catch (_) {
      // Silent — these screens surface errors from their own verify actions.
    }
  }

  Future<void> loadManualStatus() async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      manualStatus = await _manualApi.fetchMe();
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'Could not load KYC status.');
    }

    isLoading = false;

    statusLoaded = true;

    notifyListeners();
  }

  Future<bool> submitManualKyc({
    required String panNumber,
    required String fullName,
    required String dob,
    required List<XFile> panImages,
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      manualStatus = await _manualApi.submitKyc(
        panNumber: panNumber,
        fullName: fullName,
        dob: dob,
        panImages: panImages,
      );
      isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'KYC submission failed.');
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  // Legacy Cashfree helpers (kept for bank/payment screens if needed)

  Future<bool> verifyPan(String pan, {String holderName = ''}) async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      status = await _kycRepo.verifyPan(pan, holderName: holderName);

      isLoading = false;

      notifyListeners();

      if (status.panVerified) {
        await _notifyIdentityUpdated();
      }

      return status.panVerified;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'PAN verification failed.');
    }

    isLoading = false;

    notifyListeners();

    return false;
  }

  Future<String?> startAadhaarDigiLocker() async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      status = await _kycRepo.startAadhaarDigiLocker();

      isLoading = false;

      notifyListeners();

      return status.aadhaarDigiLockerUrl.isEmpty
          ? null
          : status.aadhaarDigiLockerUrl;
    } on ApiException catch (e) {
      error = _digilockerApiError(e);
    } catch (e) {
      error = _messageFromError(e, 'Could not start DigiLocker verification.');
    }

    isLoading = false;

    notifyListeners();

    return null;
  }

  Future<bool> checkAadhaarDigiLocker({String? verificationId}) async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      status = await _kycRepo.checkAadhaarDigiLocker(
        verificationId: verificationId,
      );

      isLoading = false;

      notifyListeners();

      if (status.aadhaarVerified) {
        await _notifyIdentityUpdated();
      }

      return status.aadhaarVerified;
    } on ApiException catch (e) {
      error = _digilockerApiError(e);
    } catch (e) {
      error = _messageFromError(e, 'Could not check DigiLocker verification.');
    }

    isLoading = false;

    notifyListeners();

    return false;
  }

  Future<bool> verifyBank({
    required String accountNumber,

    required String confirmAccountNumber,

    required String ifsc,

    String accountHolderName = '',
  }) async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      status = await _kycRepo.verifyBank(
        accountHolderName: accountHolderName,

        accountNumber: accountNumber,

        confirmAccountNumber: confirmAccountNumber,

        ifsc: ifsc,
      );

      isLoading = false;

      notifyListeners();

      if (status.bankVerified) {
        await _notifyIdentityUpdated();
      } else if (status.bankReviewPending) {
        error = null;
      }

      return status.bankVerified ||
          status.bankReviewStatus == 'pending' ||
          status.bankDraftReady;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'Bank verification failed.');
    }

    isLoading = false;

    notifyListeners();

    return false;
  }

  Future<bool> verifyUpi({
    required String upiVpa,
    String recipientMobile = '',
    String latlong = '28.6139,77.2090',
  }) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      status = await _kycRepo.verifyUpi(
        upiVpa: upiVpa,
        recipientMobile: recipientMobile,
        latlong: latlong,
      );
      isLoading = false;
      notifyListeners();
      if (status.upiVerified) {
        await _notifyIdentityUpdated();
      } else if (status.paymentReviewPending) {
        error = null;
      }
      return status.upiVerified ||
          status.paymentReviewPending ||
          status.identityReviewPending ||
          (status.upiManual &&
              status.upiStatus == 'pending' &&
              status.upiVpaMasked.isNotEmpty);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'UPI verification failed.');
    }
    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> uploadSelfie(List<int> imageBytes) async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      status = await _kycRepo.uploadSelfie(imageBytes);
      isLoading = false;
      notifyListeners();
      if (status.selfieReviewPending || status.selfieVerified) {
        error = null;
      }
      return status.selfieReviewPending || status.selfieVerified;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'Selfie upload failed.');
    }

    isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> runNameMatch() async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      status = await _kycRepo.runNameMatch();

      isLoading = false;

      notifyListeners();

      if (status.nameMatchPassed) {
        await _notifyIdentityUpdated();
      }

      return status.nameMatchPassed;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = _messageFromError(e, 'Name match failed.');
    }

    isLoading = false;

    notifyListeners();

    return false;
  }

  Future<PaymentSessionModel?> createPayment(
    double amount, {
    String returnUrl = '',
  }) async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      final session = await _paymentRepo.createPayment(
        amount,
        returnUrl: returnUrl,
      );

      isLoading = false;

      notifyListeners();

      return session;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Payment could not be started.';
    }

    isLoading = false;

    notifyListeners();

    return null;
  }

  Future<WithdrawResultModel?> withdraw(double amount) async {
    isLoading = true;

    error = null;

    notifyListeners();

    try {
      final result = await _paymentRepo.withdraw(amount);

      isLoading = false;

      notifyListeners();

      return result;
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Withdrawal failed.';
    }

    isLoading = false;

    notifyListeners();

    return null;
  }
}
