import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../notifications/presentation/provider/notification_provider.dart';
import '../provider/kyc_flow_provider.dart';
import '../widgets/bank_manual_review_panel.dart';
import '../widgets/kyc_widgets.dart';

class UpiVerificationScreen extends StatefulWidget {
  const UpiVerificationScreen({super.key});

  @override
  State<UpiVerificationScreen> createState() => _UpiVerificationScreenState();
}

class _UpiVerificationScreenState extends State<UpiVerificationScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _vpaController = TextEditingController();
  final _mobileController = TextEditingController();
  Timer? _pollTimer;
  bool _wasPending = false;

  bool _needsLinkedMobile(String vpa) {
    final trimmed = vpa.trim().toLowerCase();
    if (!trimmed.contains('@')) return true;
    final local = trimmed.split('@').first.replaceAll(RegExp(r'\D'), '');
    if (local.length == 10 && RegExp(r'^[6-9]').hasMatch(local)) {
      return false;
    }
    return true;
  }

  void _syncMobileFromVpa(String vpa) {
    final trimmed = vpa.trim().toLowerCase();
    if (!trimmed.contains('@')) return;
    final local = trimmed.split('@').first.replaceAll(RegExp(r'\D'), '');
    if (local.length == 10 && RegExp(r'^[6-9]').hasMatch(local)) {
      _mobileController.text = local;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _vpaController.addListener(() {
      _syncMobileFromVpa(_vpaController.text);
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _vpaController.dispose();
    _mobileController.dispose();
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
    final phone = context.read<AuthProvider>().user?.phone ?? '';
    if (phone.length == 10 && _mobileController.text.isEmpty) {
      _mobileController.text = phone;
    }
    _wasPending = kyc.status.paymentReviewPending;
    _syncPolling(kyc.status.paymentReviewPending);
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

    if (_wasPending && status.bankVerified && status.upiVerified) {
      _pollTimer?.cancel();
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;
      await context.read<NotificationProvider>().loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank & UPI verified! Continuing…')),
      );
      OnboardingFlowNavigator.goToNextKycStep(context, kyc);
      return;
    }

    _wasPending = status.paymentReviewPending;
    _syncPolling(status.paymentReviewPending);
    if (!silent) setState(() {});
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final kyc = context.read<KycFlowProvider>();
    final submitted = await kyc.verifyUpi(
      upiVpa: _vpaController.text,
      recipientMobile: _mobileController.text,
    );
    if (!mounted) return;
    if (submitted) {
      if (kyc.status.paymentReviewPending) {
        _wasPending = true;
        _syncPolling(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bank and UPI details submitted. Verification may take up to 24 hours.',
            ),
          ),
        );
        setState(() {});
        return;
      }
      if (kyc.status.upiVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UPI ID verified successfully.')),
        );
        OnboardingFlowNavigator.goToNextKycStep(context, kyc);
      }
      return;
    }
    if (kyc.error != null && kyc.error!.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(kyc.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final showLinkedMobile = _needsLinkedMobile(_vpaController.text);

    return Scaffold(
      appBar: const CustomAppBar(title: 'UPI Verification'),
      body: Consumer<KycFlowProvider>(
        builder: (context, kyc, _) {
          final status = kyc.status;
          final manualMode = status.isManualBankReview;
          final reviewPending = status.paymentReviewPending;
          final reviewRejected =
              status.bankReviewRejected ||
              (manualMode && status.upiStatus == 'failed');
          final showForm = !status.upiVerified && !reviewPending;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  showForm
                      ? (reviewRejected
                            ? 'Try again with another UPI ID'
                            : 'Enter your UPI ID')
                      : reviewPending
                      ? 'Bank & UPI under review'
                      : 'UPI ID verified',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  showForm
                      ? manualMode
                            ? 'Submit the UPI ID linked to your bank account. Our team will manually verify your bank account and UPI ID within 24 hours.'
                            : 'We validate your UPI ID and match the payee name against your PAN or bank records.'
                      : reviewPending
                      ? 'Final verification is in progress. You will be notified once approved.'
                      : 'Your UPI ID is linked and verified for payouts.',
                  style: TextStyle(color: colors.textSecondary, height: 1.45),
                ),
                if (manualMode &&
                    showForm &&
                    status.bankAccountMasked.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceSecondary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bank details saved',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${status.bankAccountMasked} · ${status.ifsc}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (reviewRejected && showForm) ...[
                  const SizedBox(height: 16),
                  BankManualReviewRejectedPanel(
                    message: status.bankReviewMessage.isNotEmpty
                        ? status.bankReviewMessage
                        : status.upiFailureReason,
                  ),
                ],
                const SizedBox(height: 24),
                if (reviewPending) ...[
                  BankManualReviewPendingPanel(status: status),
                ] else if (showForm) ...[
                  AppTextField(
                    controller: _vpaController,
                    label: 'UPI ID (VPA)',
                    hint: '8285623224@sbi or name@upi',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[a-zA-Z0-9@._-]'),
                      ),
                    ],
                    validator: (value) {
                      final vpa = (value ?? '').trim().toLowerCase();
                      if (vpa.length < 3) return 'Enter your UPI ID';
                      if (!vpa.contains('@') ||
                          vpa.startsWith('@') ||
                          vpa.endsWith('@')) {
                        return 'Enter a valid UPI ID (e.g. name@upi)';
                      }
                      return null;
                    },
                  ),
                  if (showLinkedMobile) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _mobileController,
                      label: 'Mobile linked to this UPI ID',
                      hint: '10-digit mobile number',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        if (digits.length != 10) {
                          return 'Enter the mobile number linked to this UPI ID';
                        }
                        if (!RegExp(r'^[6-9]').hasMatch(digits)) {
                          return 'Enter a valid Indian mobile number';
                        }
                        return null;
                      },
                    ),
                  ] else if (_mobileController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _mobileController,
                      label: 'Linked mobile (optional override)',
                      hint: 'Change only if UPI uses a different mobile',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        final digits = (value ?? '').replaceAll(
                          RegExp(r'\D'),
                          '',
                        );
                        if (digits.isEmpty) return null;
                        if (digits.length != 10) {
                          return 'Enter a valid 10-digit mobile number';
                        }
                        if (!RegExp(r'^[6-9]').hasMatch(digits)) {
                          return 'Enter a valid Indian mobile number';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (status.upiFailureReason.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    KycErrorBanner(message: status.upiFailureReason),
                  ],
                  if (kyc.error != null) ...[
                    const SizedBox(height: 16),
                    KycErrorBanner(message: kyc.error!),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: kyc.isLoading
                        ? 'Submitting…'
                        : manualMode
                        ? 'Submit bank & UPI for verification'
                        : 'Verify UPI ID',
                    onPressed: kyc.isLoading ? null : _verify,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.greenSoft.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              manualMode
                                  ? 'Verified manually'
                                  : 'Verified via ${status.upiVerificationProvider}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          status.upiVpaMasked,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary,
                          ),
                        ),
                        if (status.upiName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            status.upiName,
                            style: TextStyle(color: colors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue to Name Match',
                    onPressed: () => context.push(AppRoutes.nameMatch),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
