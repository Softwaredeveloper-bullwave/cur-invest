import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../domain/kyc_models.dart';
import 'dio_client.dart';

export 'payment_repository.dart';

/// Automated KYC step API client (PAN, Aadhaar DigiLocker, bank, UPI, name match).
class KycRepository {
  final _client = KycDioClient.instance;

  Future<KycStatusModel> fetchStatus() async {
    final data = await _client.getJson('/kyc-status/');
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> verifyPan(String pan, {String holderName = ''}) async {
    final data = await _client.postJson(
      '/verify-pan/',
      body: {
        'pan_number': pan.toUpperCase(),
        if (holderName.isNotEmpty) 'holder_name': holderName,
      },
    );
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> startAadhaarDigiLocker() async {
    final data = await _client.postJson('/start-aadhaar-digilocker/');
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> checkAadhaarDigiLocker({
    String? verificationId,
  }) async {
    final data = await _client.postJson(
      '/check-aadhaar-digilocker/',
      body: {
        if (verificationId != null && verificationId.trim().isNotEmpty)
          'verification_id': verificationId.trim(),
      },
    );
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> verifyBank({
    required String accountNumber,
    required String confirmAccountNumber,
    required String ifsc,
    String accountHolderName = '',
  }) async {
    final data = await _client.postJson(
      '/verify-bank/',
      body: {
        if (accountHolderName.trim().isNotEmpty)
          'account_holder_name': accountHolderName.trim(),
        'account_number': accountNumber,
        'confirm_account_number': confirmAccountNumber,
        'ifsc': ifsc.toUpperCase(),
      },
    );
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> verifyUpi({
    required String upiVpa,
    String recipientMobile = '',
    String latlong = '28.6139,77.2090',
  }) async {
    final data = await _client.postJson(
      '/verify-upi/',
      body: {
        'upi_vpa': upiVpa.trim().toLowerCase(),
        if (recipientMobile.trim().isNotEmpty)
          'recipient_mobile': recipientMobile.trim(),
        if (latlong.isNotEmpty) 'latlong': latlong,
      },
    );
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> runNameMatch() async {
    final data = await _client.postJson('/name-match/');
    return KycStatusModel.fromJson(data);
  }

  Future<KycStatusModel> uploadSelfie(List<int> imageBytes) async {
    final form = FormData.fromMap({
      'selfie': MultipartFile.fromBytes(
        imageBytes,
        filename: 'selfie.jpg',
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    try {
      final res = await _client.dio.post<Map<String, dynamic>>(
        '/upload-selfie/',
        data: form,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      return KycStatusModel.fromJson(res.data ?? {});
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }
}
