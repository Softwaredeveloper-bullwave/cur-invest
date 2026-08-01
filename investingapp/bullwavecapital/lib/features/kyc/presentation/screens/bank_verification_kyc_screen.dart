import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../notifications/presentation/provider/notification_provider.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/bank_form_widgets.dart';
import '../widgets/bank_manual_review_panel.dart';
import '../widgets/bank_selection_section.dart';
import '../widgets/bank_verification_result_card.dart';
import '../widgets/kyc_widgets.dart';

class BankVerificationKycScreen extends StatefulWidget {
  const BankVerificationKycScreen({super.key});

  @override
  State<BankVerificationKycScreen> createState() =>
      _BankVerificationKycScreenState();
}

class _BankVerificationKycScreenState extends State<BankVerificationKycScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _accountController = TextEditingController();
  final _confirmController = TextEditingController();
  final _ifscController = TextEditingController();
  final _holderController = TextEditingController();
  bool _isUpdating = false;
  Timer? _pollTimer;
  bool _wasPending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _accountController.dispose();
    _confirmController.dispose();
    _ifscController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus(silent: true);
    }
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final kyc = context.read<KycFlowProvider>();
    await kyc.loadKycStatus();
    if (!mounted) return;
    final status = kyc.status;
    if (status.ifsc.isNotEmpty) {
      _ifscController.text = status.ifsc;
    }
    if (status.panName.isNotEmpty && !status.bankSkipIdentityMatch) {
      _holderController.text = status.panName;
    } else if (status.accountHolderName.isNotEmpty) {
      _holderController.text = status.accountHolderName;
    }
    _wasPending = status.bankReviewPending;
    _syncPolling(status.bankReviewPending);
  }

  void _syncPolling(bool pending) {
    _pollTimer?.cancel();
    if (!pending) return;
    _pollTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      _refreshStatus(silent: true);
    });
  }

  Future<void> _refreshStatus({bool silent = false}) async {
    if (!mounted) return;
    final kyc = context.read<KycFlowProvider>();
    await kyc.loadKycStatus();
    if (!mounted) return;
    final status = kyc.status;

    if (_wasPending && status.bankVerified) {
      _pollTimer?.cancel();
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      await context.read<NotificationProvider>().loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bank account verified! Welcome back.'),
        ),
      );
      context.go(AppRoutes.home);
      return;
    }

    _wasPending = status.bankReviewPending;
    _syncPolling(status.bankReviewPending);
    if (!silent) setState(() {});
  }

  void _startUpdate() {
    setState(() {
      _isUpdating = true;
      _accountController.clear();
      _confirmController.clear();
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final kyc = context.read<KycFlowProvider>();
    final submitted = await kyc.verifyBank(
      accountNumber: _accountController.text,
      confirmAccountNumber: _confirmController.text,
      ifsc: _ifscController.text,
      accountHolderName: _holderController.text.trim(),
    );
    if (!mounted) return;

    if (submitted) {
      setState(() => _isUpdating = false);
      if (kyc.status.bankReviewPending) {
        _wasPending = true;
        _syncPolling(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bank details submitted. Final verification may take up to 24 hours.',
            ),
          ),
        );
      } else if (kyc.status.bankVerified) {
        await context.read<AuthProvider>().refreshProfile();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bank account verified successfully via Eko.'),
          ),
        );
        OnboardingFlowNavigator.goToNextKycStep(context, kyc);
      }
      return;
    }

    if (kyc.error != null && kyc.error!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kyc.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: _isUpdating ? 'Update Bank Account' : 'Bank Verification',
      ),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final status = kyc.status;
          final manualMode = status.isManualBankReview;
          final bankReviewPending = status.bankReviewPending;
          final bankReviewRejected =
              status.bankReviewRejected || (manualMode && status.bankStatus == 'failed');
          final bankDraftSaved = manualMode && status.bankDraftReady;
          final showForm =
              ((!status.bankVerified && !bankReviewPending && !bankDraftSaved) ||
                  _isUpdating);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  showForm
                      ? (bankReviewRejected
                          ? 'Try again with another bank account'
                          : 'Enter your bank account details')
                      : bankReviewPending
                      ? 'Bank verification under review'
                      : 'Bank account verified',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  showForm
                      ? (manualMode
                          ? 'Submit your account number and IFSC, then enter your UPI ID on the next screen. Our team will manually verify both within 24 hours.'
                          : (status.bankVerificationProvider == 'eko'
                              ? (status.bankSkipIdentityMatch
                                  ? 'Testing mode: Eko verifies the account exists. PAN name match is disabled.'
                                  : 'Your bank account is verified live via Eko. The account must be in your name as per your verified PAN.')
                              : (status.bankSkipIdentityMatch
                                  ? 'Testing mode: bank account check only. PAN name match is disabled.'
                                  : 'Account number and IFSC are verified live via Cashfree Secure ID. The account must match your PAN name.')))
                      : bankReviewPending
                      ? 'Final verification is in progress. You will be notified once approved.'
                      : 'Your linked account is verified. You can update it if your bank details change.',
                  style: const TextStyle(height: 1.45),
                ),
                if (bankReviewRejected && showForm && !bankReviewPending) ...[
                  const SizedBox(height: 16),
                  BankManualReviewRejectedPanel(
                    message: status.bankReviewMessage.isNotEmpty
                        ? status.bankReviewMessage
                        : status.bankFailureReason,
                  ),
                ],
                if (showForm &&
                    !manualMode &&
                    status.cashfreeSandbox &&
                    status.bankVerificationProvider == 'cashfree' &&
                    status.sandboxTestBank.successAccountNumber.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.brandOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.brandOrange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cashfree Sandbox — use official test accounts',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Real PNB/HDFC accounts do not work in sandbox.\n'
                          '✅ Success test: ${status.sandboxTestBank.successAccountNumber} / ${status.sandboxTestBank.successIfsc}\n'
                          '❌ Invalid test: ${status.sandboxTestBank.invalidAccountNumber} / ${status.sandboxTestBank.successIfsc}',
                          style: const TextStyle(fontSize: 13, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
                if (showForm &&
                    !manualMode &&
                    (status.bankFailureReason.isNotEmpty ||
                        status.bankVerificationLogs.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  BankVerificationLogsCard(
                    failureReason: status.bankFailureReason,
                    logs: status.bankVerificationLogs,
                  ),
                ],
                const SizedBox(height: 24),
                if (showForm) ...[
                  const FormSectionHeader(
                    title: 'Account Details',
                    subtitle: 'Re-enter full account number when updating',
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _holderController,
                    label: 'Account Holder Name',
                    readOnly:
                        status.panVerified &&
                        status.panName.isNotEmpty &&
                        !status.bankSkipIdentityMatch,
                    validator: (value) =>
                        value == null || value.trim().length < 3
                            ? 'Enter the name on your bank account'
                            : null,
                  ),
                  if (status.bankSkipIdentityMatch) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Testing mode enabled — enter the real account holder name for this bank account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.brandOrange,
                        height: 1.4,
                      ),
                    ),
                  ] else if (status.panVerified && status.panName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Must match your verified PAN name: ${status.panName}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _accountController,
                    label: 'Account Number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) => value == null || value.length < 9
                        ? 'Enter valid account number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _confirmController,
                    label: 'Confirm Account Number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.length < 9) {
                        return 'Confirm your account number';
                      }
                      if (value != _accountController.text) {
                        return 'Account numbers do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  BankSelectionSection(
                    ifscController: _ifscController,
                    enabled: !kyc.isLoading,
                    onIfscResolved: (_) {},
                  ),
                  if (kyc.error != null) ...[
                    const SizedBox(height: 16),
                    KycErrorBanner(message: kyc.error!),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: kyc.isLoading
                        ? 'Submitting…'
                        : manualMode
                        ? (_isUpdating
                            ? 'Submit updated details'
                            : 'Continue to UPI verification')
                        : (_isUpdating
                            ? 'Update & Verify Bank'
                            : 'Verify Bank Account'),
                    onPressed: kyc.isLoading ? null : _verify,
                  ),
                  if (_isUpdating) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: kyc.isLoading
                            ? null
                            : () => setState(() => _isUpdating = false),
                        child: const Text('Cancel update'),
                      ),
                    ),
                  ],
                ] else ...[
                  if (bankReviewPending) ...[
                    BankManualReviewPendingPanel(status: status),
                    const SizedBox(height: 16),
                    BankVerificationResultCard(status: status, showMethod: false),
                  ] else if (manualMode && status.bankDraftReady && kyc.upiRequired && status.canProceedToIdentity) ...[
                    BankVerificationResultCard(status: status, showMethod: false),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      label: 'Continue to identity verification',
                      onPressed: () => context.push(AppRoutes.identityVerification),
                    ),
                  ] else ...[
                    BankVerificationResultCard(status: status),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _startUpdate,
                      child: const Text('Update Bank Account'),
                    ),
                    if (kyc.upiRequired && !status.upiVerified && status.canProceedToIdentity) ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Continue to identity verification',
                        onPressed: () => context.push(AppRoutes.identityVerification),
                      ),
                    ] else if (!status.nameMatchPassed) ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Continue to Name Match',
                        onPressed: () => context.push(AppRoutes.nameMatch),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Continue',
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                    ],
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
