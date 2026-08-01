class StepProvidersModel {
  final String pan;
  final String bank;
  final String upi;
  final String aadhaar;
  final String legacy;

  const StepProvidersModel({
    this.pan = 'cashfree',
    this.bank = 'cashfree',
    this.upi = 'cashfree',
    this.aadhaar = 'eko',
    this.legacy = 'cashfree',
  });

  factory StepProvidersModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const StepProvidersModel();
    return StepProvidersModel(
      pan: json['pan'] as String? ?? 'cashfree',
      bank: json['bank'] as String? ?? 'cashfree',
      upi: json['upi'] as String? ?? 'cashfree',
      aadhaar: json['aadhaar'] as String? ?? 'eko',
      legacy: json['legacy'] as String? ?? 'cashfree',
    );
  }
}

class BankVerificationLogModel {
  final String time;
  final String status;
  final String message;
  final String accountMasked;
  final String ifsc;

  const BankVerificationLogModel({
    this.time = '',
    this.status = '',
    this.message = '',
    this.accountMasked = '',
    this.ifsc = '',
  });

  factory BankVerificationLogModel.fromJson(Map<String, dynamic> json) {
    return BankVerificationLogModel(
      time: json['time'] as String? ?? '',
      status: json['status'] as String? ?? '',
      message: json['message'] as String? ?? '',
      accountMasked: json['accountMasked'] as String? ?? '',
      ifsc: json['ifsc'] as String? ?? '',
    );
  }
}

class SandboxTestBankModel {
  final String successAccountNumber;
  final String successIfsc;
  final String invalidAccountNumber;
  final String invalidIfsc;

  const SandboxTestBankModel({
    this.successAccountNumber = '',
    this.successIfsc = '',
    this.invalidAccountNumber = '',
    this.invalidIfsc = '',
  });

  factory SandboxTestBankModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SandboxTestBankModel();
    return SandboxTestBankModel(
      successAccountNumber: json['successAccountNumber'] as String? ?? '',
      successIfsc: json['successIfsc'] as String? ?? '',
      invalidAccountNumber: json['invalidAccountNumber'] as String? ?? '',
      invalidIfsc: json['invalidIfsc'] as String? ?? '',
    );
  }
}

class KycStatusModel {
  final String provider;
  final String kycMode;
  final bool upiRequired;
  final bool upiManual;
  final bool identityReviewPending;
  final bool manualFinalApprovalRequired;
  final bool finalKycApproved;
  final StepProvidersModel stepProviders;
  final bool cashfreeSandbox;
  final String bankVerificationProvider;
  final String upiVerificationProvider;
  final SandboxTestBankModel sandboxTestBank;
  final bool mobileVerified;
  final bool panVerified;
  final bool aadhaarVerified;
  final bool bankVerified;
  final bool bankReadyForIdentity;
  final bool upiVerified;
  final bool selfieVerified;
  final String selfieStatus;
  final String selfieUrl;
  final bool selfieReviewPending;
  final String selfieReviewMessage;
  final String? selfieReviewDueAt;
  final bool nameMatchPassed;
  final String overallStatus;
  final String panNumberMasked;
  final String panName;
  final String panStatus;
  final String aadhaarNumberMasked;
  final String aadhaarName;
  final String aadhaarStatus;
  final String aadhaarVerificationMethod;
  final bool aadhaarDigiLockerPending;
  final String aadhaarDigiLockerUrl;
  final bool aadhaarOtpSent;
  final bool aadhaarRequiresSenderOtp;
  final String bankName;
  final String bankBranch;
  final String accountHolderName;
  final String bankAccountMasked;
  final String ifsc;
  final String bankStatus;
  final String bankFailureReason;
  final List<BankVerificationLogModel> bankVerificationLogs;
  final String bankVerificationMethod;
  final String bankReviewMode;
  final String bankReviewStatus;
  final String bankReviewMessage;
  final String? bankReviewDueAt;
  final bool bankDraftReady;
  final bool paymentReviewPending;
  final bool bankSkipIdentityMatch;
  final String upiVpaMasked;
  final String upiName;
  final String upiStatus;
  final String upiFailureReason;
  final double upiNameMatchScore;
  final String nameAtBank;
  final String nameMatchResult;
  final double nameMatchScore;
  final String? verifiedAt;

  const KycStatusModel({
    this.provider = 'cashfree',
    this.kycMode = 'manual',
    this.upiRequired = true,
    this.upiManual = false,
    this.identityReviewPending = false,
    this.manualFinalApprovalRequired = false,
    this.finalKycApproved = false,
    this.stepProviders = const StepProvidersModel(),
    this.cashfreeSandbox = false,
    this.bankVerificationProvider = 'cashfree',
    this.upiVerificationProvider = 'cashfree',
    this.sandboxTestBank = const SandboxTestBankModel(),
    required this.mobileVerified,
    required this.panVerified,
    this.aadhaarVerified = false,
    required this.bankVerified,
    this.bankReadyForIdentity = false,
    this.upiVerified = false,
    this.selfieVerified = false,
    this.selfieStatus = 'pending',
    this.selfieUrl = '',
    this.selfieReviewPending = false,
    this.selfieReviewMessage = '',
    this.selfieReviewDueAt,
    required this.nameMatchPassed,
    required this.overallStatus,
    required this.panNumberMasked,
    required this.panName,
    required this.panStatus,
    this.aadhaarNumberMasked = '',
    this.aadhaarName = '',
    this.aadhaarStatus = 'pending',
    this.aadhaarVerificationMethod = 'digilocker',
    this.aadhaarDigiLockerPending = false,
    this.aadhaarDigiLockerUrl = '',
    this.aadhaarOtpSent = false,
    this.aadhaarRequiresSenderOtp = false,
    required this.bankName,
    required this.bankBranch,
    required this.accountHolderName,
    required this.bankAccountMasked,
    required this.ifsc,
    required this.bankStatus,
    this.bankFailureReason = '',
    this.bankVerificationLogs = const [],
    this.bankVerificationMethod = '',
    this.bankReviewMode = 'provider',
    this.bankReviewStatus = '',
    this.bankReviewMessage = '',
    this.bankReviewDueAt,
    this.bankDraftReady = false,
    this.paymentReviewPending = false,
    this.bankSkipIdentityMatch = false,
    this.upiVpaMasked = '',
    this.upiName = '',
    this.upiStatus = 'pending',
    this.upiFailureReason = '',
    this.upiNameMatchScore = 0,
    required this.nameAtBank,
    required this.nameMatchResult,
    required this.nameMatchScore,
    this.verifiedAt,
  });

  bool get usesAutomatedKyc =>
      kycMode == 'automated' ||
      panVerified ||
      stepProviders.pan == 'eko' ||
      stepProviders.bank == 'eko' ||
      stepProviders.aadhaar == 'eko';

  bool get isFullyVerified => overallStatus.toLowerCase() == 'verified';

  bool get isManualBankReview => bankReviewMode == 'manual';

  bool get bankReviewPending => paymentReviewPending || bankReviewStatus == 'pending';

  bool get bankReviewRejected => bankReviewStatus == 'rejected';

  bool get selfieReviewRejected => selfieStatus == 'rejected';

  bool get selfieUploaded =>
      selfieReviewPending || selfieVerified || selfieStatus == 'completed';

  bool get canProceedToIdentity =>
      bankReadyForIdentity || bankVerified || (isManualBankReview && bankDraftReady);

  factory KycStatusModel.fromJson(Map<String, dynamic> json) => KycStatusModel(
    provider: json['provider'] as String? ?? 'cashfree',
    kycMode: json['kycMode'] as String? ?? 'manual',
    upiRequired: json['upiRequired'] as bool? ?? true,
    upiManual: json['upiManual'] as bool? ?? false,
    identityReviewPending: json['identityReviewPending'] as bool? ?? false,
    manualFinalApprovalRequired: json['manualFinalApprovalRequired'] as bool? ?? false,
    finalKycApproved: json['finalKycApproved'] as bool? ?? false,
    stepProviders: StepProvidersModel.fromJson(
      json['stepProviders'] as Map<String, dynamic>?,
    ),
    cashfreeSandbox: json['cashfreeSandbox'] as bool? ?? false,
    bankVerificationProvider:
        json['bankVerificationProvider'] as String? ?? 'cashfree',
    upiVerificationProvider:
        json['upiVerificationProvider'] as String? ?? 'cashfree',
    sandboxTestBank: SandboxTestBankModel.fromJson(
      json['sandboxTestBank'] as Map<String, dynamic>?,
    ),
    mobileVerified: json['mobileVerified'] as bool? ?? false,
    panVerified: json['panVerified'] as bool? ?? false,
    aadhaarVerified: json['aadhaarVerified'] as bool? ?? false,
    bankVerified: json['bankVerified'] as bool? ?? false,
    bankReadyForIdentity: json['bankReadyForIdentity'] as bool? ??
        (json['bankVerified'] as bool? ?? false),
    upiVerified: json['upiVerified'] as bool? ?? false,
    selfieVerified: json['selfieVerified'] as bool? ?? false,
    selfieStatus: json['selfieStatus'] as String? ?? 'pending',
    selfieUrl: json['selfieUrl'] as String? ?? '',
    selfieReviewPending: json['selfieReviewPending'] as bool? ?? false,
    selfieReviewMessage: json['selfieReviewMessage'] as String? ?? '',
    selfieReviewDueAt: json['selfieReviewDueAt'] as String?,
    nameMatchPassed: json['nameMatchPassed'] as bool? ?? false,
    overallStatus: json['overallStatus'] as String? ?? 'pending',
    panNumberMasked: json['panNumberMasked'] as String? ?? '',
    panName: json['panName'] as String? ?? '',
    panStatus: json['panStatus'] as String? ?? 'pending',
    aadhaarNumberMasked: json['aadhaarNumberMasked'] as String? ?? '',
    aadhaarName: json['aadhaarName'] as String? ?? '',
    aadhaarStatus: json['aadhaarStatus'] as String? ?? 'pending',
    aadhaarVerificationMethod:
        json['aadhaarVerificationMethod'] as String? ?? 'digilocker',
    aadhaarDigiLockerPending:
        json['aadhaarDigiLockerPending'] as bool? ?? false,
    aadhaarDigiLockerUrl: json['aadhaarDigiLockerUrl'] as String? ?? '',
    aadhaarOtpSent: json['aadhaarOtpSent'] as bool? ?? false,
    aadhaarRequiresSenderOtp:
        json['aadhaarRequiresSenderOtp'] as bool? ?? false,
    bankName: json['bankName'] as String? ?? '',
    bankBranch: json['bankBranch'] as String? ?? '',
    accountHolderName: json['accountHolderName'] as String? ?? '',
    bankAccountMasked: json['bankAccountMasked'] as String? ?? '',
    ifsc: json['ifsc'] as String? ?? '',
    bankStatus: json['bankStatus'] as String? ?? 'pending',
    bankFailureReason: json['bankFailureReason'] as String? ?? '',
    bankVerificationLogs:
        (json['bankVerificationLogs'] as List<dynamic>?)
            ?.map(
              (e) =>
                  BankVerificationLogModel.fromJson(e as Map<String, dynamic>),
            )
            .toList() ??
        const [],
    bankVerificationMethod: json['bankVerificationMethod'] as String? ?? '',
    bankReviewMode: json['bankReviewMode'] as String? ?? 'provider',
    bankReviewStatus: json['bankReviewStatus'] as String? ?? '',
    bankReviewMessage: json['bankReviewMessage'] as String? ?? '',
    bankReviewDueAt: json['bankReviewDueAt'] as String?,
    bankDraftReady: json['bankDraftReady'] as bool? ?? false,
    paymentReviewPending: json['paymentReviewPending'] as bool? ?? false,
    bankSkipIdentityMatch: json['bankSkipIdentityMatch'] as bool? ?? false,
    upiVpaMasked: json['upiVpaMasked'] as String? ?? '',
    upiName: json['upiName'] as String? ?? '',
    upiStatus: json['upiStatus'] as String? ?? 'pending',
    upiFailureReason: json['upiFailureReason'] as String? ?? '',
    upiNameMatchScore: (json['upiNameMatchScore'] as num?)?.toDouble() ?? 0,
    nameAtBank: json['nameAtBank'] as String? ?? '',
    nameMatchResult: json['nameMatchResult'] as String? ?? '',
    nameMatchScore: (json['nameMatchScore'] as num?)?.toDouble() ?? 0,
    verifiedAt: json['verifiedAt'] as String?,
  );

  static const empty = KycStatusModel(
    provider: 'cashfree',
    kycMode: 'manual',
    upiRequired: true,
    stepProviders: StepProvidersModel(),
    cashfreeSandbox: false,
    bankVerificationProvider: 'eko',
    upiVerificationProvider: 'eko',
    sandboxTestBank: SandboxTestBankModel(),
    mobileVerified: false,
    panVerified: false,
    aadhaarVerified: false,
    bankVerified: false,
    bankReadyForIdentity: false,
    upiVerified: false,
    selfieVerified: false,
    selfieStatus: 'pending',
    selfieUrl: '',
    selfieReviewPending: false,
    selfieReviewMessage: '',
    nameMatchPassed: false,
    overallStatus: 'pending',
    panNumberMasked: '',
    panName: '',
    panStatus: 'pending',
    aadhaarNumberMasked: '',
    aadhaarName: '',
    aadhaarStatus: 'pending',
    aadhaarVerificationMethod: 'digilocker',
    aadhaarDigiLockerPending: false,
    aadhaarDigiLockerUrl: '',
    aadhaarOtpSent: false,
    aadhaarRequiresSenderOtp: false,
    bankName: '',
    bankBranch: '',
    accountHolderName: '',
    bankAccountMasked: '',
    ifsc: '',
    bankStatus: 'pending',
    bankFailureReason: '',
    bankVerificationLogs: [],
    bankVerificationMethod: '',
    bankReviewMode: 'provider',
    bankReviewStatus: '',
    bankReviewMessage: '',
    upiVpaMasked: '',
    upiName: '',
    upiStatus: 'pending',
    upiFailureReason: '',
    upiNameMatchScore: 0,
    nameAtBank: '',
    nameMatchResult: '',
    nameMatchScore: 0,
  );
}

class PaymentSessionModel {
  final String orderId;
  final String paymentSessionId;
  final double amount;
  final String currency;
  final String environment;
  final bool devMode;
  final bool success;
  final String message;

  const PaymentSessionModel({
    required this.orderId,
    required this.paymentSessionId,
    required this.amount,
    required this.currency,
    required this.environment,
    this.devMode = false,
    this.success = false,
    this.message = '',
  });

  factory PaymentSessionModel.fromJson(Map<String, dynamic> json) =>
      PaymentSessionModel(
        orderId: json['orderId'] as String? ?? '',
        paymentSessionId: json['paymentSessionId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] as String? ?? 'INR',
        environment: json['environment'] as String? ?? 'SANDBOX',
        devMode: json['devMode'] as bool? ?? false,
        success: json['success'] as bool? ?? false,
        message: json['message'] as String? ?? '',
      );
}

class WithdrawResultModel {
  final bool success;
  final String referenceId;
  final String status;
  final double balance;

  const WithdrawResultModel({
    required this.success,
    required this.referenceId,
    required this.status,
    required this.balance,
  });

  factory WithdrawResultModel.fromJson(Map<String, dynamic> json) =>
      WithdrawResultModel(
        success: json['success'] as bool? ?? false,
        referenceId: json['referenceId'] as String? ?? '',
        status: json['status'] as String? ?? 'submitted',
        balance: (json['balance'] as num?)?.toDouble() ?? 0,
      );
}
