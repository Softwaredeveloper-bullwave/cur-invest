import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/refresh_providers.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/payments/cashfree_checkout_service.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../presentation/provider/wallet_provider.dart';

class DepositSuccessScreen extends StatefulWidget {
  const DepositSuccessScreen({super.key});

  @override
  State<DepositSuccessScreen> createState() => _DepositSuccessScreenState();
}

class _DepositSuccessScreenState extends State<DepositSuccessScreen> {
  bool _verifying = true;
  bool _verified = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _finalizeDeposit());
  }

  Future<void> _finalizeDeposit() async {
    final params = GoRouterState.of(context).uri.queryParameters;
    final orderId = params['orderId'] ?? params['order_id'] ?? '';
    final amount = double.tryParse(params['amount'] ?? '') ?? 0;

    if (orderId.isEmpty) {
      setState(() {
        _verifying = false;
        _verified = false;
        _error =
            'Payment reference missing. Return from Cashfree checkout or check your wallet balance.';
      });
      return;
    }

    final result = await CashfreeCheckoutService.instance.confirmOrder(orderId);
    if (!mounted) return;

    if (result.status == CashfreeCheckoutStatus.success) {
      await context.read<WalletProvider>().loadData();
      await refreshAllProviders(context);
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = true;
      });
      return;
    }

    if (result.status == CashfreeCheckoutStatus.unavailable) {
      await context.read<WalletProvider>().loadData();
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verified = false;
        _error = result.message.isNotEmpty
            ? result.message
            : 'Payment received but not confirmed yet. Pull to refresh your wallet.';
      });
      return;
    }

    setState(() {
      _verifying = false;
      _verified = false;
      _error = result.message.isNotEmpty
          ? result.message
          : 'Could not confirm payment for order $orderId.';
    });

    if (amount <= 0) return;
  }

  @override
  Widget build(BuildContext context) {
    final params = GoRouterState.of(context).uri.queryParameters;
    final amount = double.tryParse(params['amount'] ?? '') ?? 0;

    if (_verifying) {
      return const Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Confirming your payment…'),
              ],
            ),
          ),
        ),
      );
    }

    if (!_verified) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 72),
                const SizedBox(height: 16),
                Text(
                  'Payment pending',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _error ?? 'We could not confirm your payment yet.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Go to Wallet',
                  onPressed: () => context.go(AppRoutes.wallet),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 72,
                ),
              ),
              const SizedBox(height: AppDimensions.paddingLg),
              Text(
                'Deposit Successful!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              if (amount > 0) ...[
                Text(
                  CurrencyFormatter.format(amount),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Your wallet balance has been updated.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.paddingXl),
              PrimaryButton(
                label: 'Go to Wallet',
                onPressed: () => context.go(AppRoutes.wallet),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
