import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/payments/cashfree_checkout_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/wallet_provider.dart';

class DepositScreen extends StatefulWidget {
  const DepositScreen({super.key});

  @override
  State<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends State<DepositScreen> {
  final _amountController = TextEditingController();
  String _statusMessage = '';
  bool _paying = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _webReturnUrl(double amount) {
    if (!CashfreeCheckoutService.canUseRedirectReturnUrl) return null;
    final base = Uri.base;
    final path = base.path.isEmpty ? '/' : base.path;
    return '${base.origin}$path#/deposit/success?amount=$amount&order_id={order_id}';
  }

  Future<void> _proceed() async {
    if (_paying) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount (min ₹1)')),
      );
      return;
    }

    setState(() {
      _paying = true;
      _statusMessage = '';
    });

    final kyc = context.read<KycFlowProvider>();
    final session = await kyc.createPayment(
      amount,
      returnUrl: _webReturnUrl(amount) ?? '',
    );

    if (!mounted) return;

    if (session == null) {
      setState(() => _paying = false);
      return;
    }

    if (session.devMode && session.success) {
      await context.read<WalletProvider>().loadData();
      await refreshAllProviders(context);
      if (!mounted) return;
      setState(() => _paying = false);
      context.push('${AppRoutes.depositSuccess}?amount=$amount');
      return;
    }

    final checkout = await CashfreeCheckoutService.instance.startCheckout(
      session,
    );
    if (!mounted) return;

    switch (checkout.status) {
      case CashfreeCheckoutStatus.redirected:
        setState(() {
          _paying = false;
          _statusMessage =
              'Complete payment on the Cashfree page. '
              'You will return here automatically.';
        });
        return;
      case CashfreeCheckoutStatus.success:
        await context.read<WalletProvider>().loadData();
        await refreshAllProviders(context);
        if (!mounted) return;
        setState(() => _paying = false);
        context.push(
          '${AppRoutes.depositSuccess}?amount=$amount&orderId=${session.orderId}',
        );
        return;
      case CashfreeCheckoutStatus.cancelled:
        setState(() {
          _paying = false;
          _statusMessage = checkout.message.isNotEmpty
              ? checkout.message
              : 'Payment cancelled.';
        });
        return;
      case CashfreeCheckoutStatus.unavailable:
        setState(() {
          _paying = false;
          _statusMessage = checkout.message;
        });
        return;
      case CashfreeCheckoutStatus.failed:
        setState(() => _paying = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              checkout.message.isNotEmpty
                  ? checkout.message
                  : 'Could not complete Cashfree payment.',
            ),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kycLoading = context.watch<KycFlowProvider>().isLoading;
    final busy = _paying || kycLoading;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Add Money'),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(
              controller: _amountController,
              label: 'Amount',
              hint: 'Enter amount in ₹',
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.currency_rupee),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text(
              'Pay securely with Cashfree — UPI, cards, or net banking.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
            ],
            const Spacer(),
            Consumer<KycFlowProvider>(
              builder: (context, kycFlow, _) => Column(
                children: [
                  PrimaryButton(
                    label: busy ? 'Processing…' : 'Pay with Cashfree',
                    onPressed: busy ? null : _proceed,
                  ),
                  if (kycFlow.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      kycFlow.error!,
                      style: const TextStyle(
                        color: AppColors.red,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
