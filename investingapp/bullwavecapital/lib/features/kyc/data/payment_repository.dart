import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../domain/kyc_models.dart';
import 'dio_client.dart';

class PaymentRepository {
  final _client = KycDioClient.instance;

  Future<PaymentSessionModel> createPayment(double amount, {String returnUrl = ''}) async {
    try {
      final data = await _client.postJson('/create-payment/', body: {
        'amount': amount,
        if (returnUrl.isNotEmpty) 'return_url': returnUrl,
      });
      return PaymentSessionModel.fromJson(data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  Future<WithdrawResultModel> withdraw(double amount) async {
    try {
      final data = await _client.postJson('/withdraw/', body: {'amount': amount});
      return WithdrawResultModel.fromJson(data);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }

  Future<String> paymentStatus(String orderId, {bool sync = false}) async {
    final data = await _client.getJson(
      '/payment-status/$orderId/',
      queryParameters: sync ? {'sync': 'true'} : null,
    );
    return data['status'] as String? ?? 'created';
  }

  /// Confirm payment with Cashfree and credit wallet (post-checkout on mobile).
  Future<Map<String, dynamic>> verifyPayment(String orderId) async {
    try {
      final data = await _client.postJson('/verify-payment/', body: {'orderId': orderId});
      return data;
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error!;
      rethrow;
    }
  }
}
