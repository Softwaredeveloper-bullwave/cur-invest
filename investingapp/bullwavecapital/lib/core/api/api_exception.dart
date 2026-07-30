class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  const ApiException(this.statusCode, this.message, {this.code});

  bool get isFraud =>
      code == 'fraud_account' ||
      code == 'fraud_detected' ||
      message.toLowerCase().contains('fraud');

  bool get isIpBlocked =>
      code == 'ip_not_whitelisted' ||
      code == 'ip_validation_failed' ||
      message.toLowerCase().contains('ip not whitelisted');

  @override
  String toString() => message;
}
