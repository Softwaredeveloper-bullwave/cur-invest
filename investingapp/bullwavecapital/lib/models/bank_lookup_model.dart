class BankOption {
  const BankOption({required this.code, required this.name});

  final String code;
  final String name;

  factory BankOption.fromJson(Map<String, dynamic> json) {
    return BankOption(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class BankBranchOption {
  const BankBranchOption({
    required this.ifsc,
    required this.branch,
    required this.bank,
    required this.bankCode,
    required this.city,
    required this.district,
    required this.state,
    this.address = '',
  });

  final String ifsc;
  final String branch;
  final String bank;
  final String bankCode;
  final String city;
  final String district;
  final String state;
  final String address;

  factory BankBranchOption.fromJson(Map<String, dynamic> json) {
    return BankBranchOption(
      ifsc: json['ifsc']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      bank: json['bank']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}

class IfscLookupResult {
  const IfscLookupResult({
    required this.ifsc,
    required this.bank,
    required this.bankCode,
    required this.branch,
    required this.city,
    required this.district,
    required this.state,
    this.address = '',
  });

  final String ifsc;
  final String bank;
  final String bankCode;
  final String branch;
  final String city;
  final String district;
  final String state;
  final String address;

  factory IfscLookupResult.fromJson(Map<String, dynamic> json) {
    return IfscLookupResult(
      ifsc: json['ifsc']?.toString() ?? '',
      bank: json['bank']?.toString() ?? '',
      bankCode: json['bankCode']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      district: json['district']?.toString() ?? json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }
}
