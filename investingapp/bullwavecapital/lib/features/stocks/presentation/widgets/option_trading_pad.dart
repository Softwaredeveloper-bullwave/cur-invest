import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/app_navigation.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/widgets/expiry_highlight.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/option_trading_provider.dart';
import '../utils/option_trading_flow.dart';
import 'option_order_success_sheet.dart';
import 'scalper_controls.dart';

class OptionTradingPad extends StatefulWidget {
  final OptionContractModel contract;
  final OptionChainContext chainContext;
  final String initialSide;

  const OptionTradingPad({
    super.key,
    required this.contract,
    required this.chainContext,
    this.initialSide = 'BUY',
  });

  static Future<void> show(
    BuildContext context, {
    required OptionContractModel contract,
    required OptionChainContext chainContext,
    String initialSide = 'BUY',
  }) {
    return AppNavigation.showAppBottomSheet<void>(
      context,
      builder: (_) => OptionTradingPad(
        contract: contract,
        chainContext: chainContext,
        initialSide: initialSide,
      ),
    );
  }

  @override
  State<OptionTradingPad> createState() => _OptionTradingPadState();
}

class _OptionTradingPadState extends State<OptionTradingPad> {
  late String _side;
  late final TextEditingController _qtyController;
  bool _isPlacing = false;
  ScalperOrderConfig _scalper = const ScalperOrderConfig();

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide == 'SELL' ? 'SELL' : 'BUY';
    _qtyController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  bool get _isSell => _side == 'SELL';

  int get _qty {
    final parsed = int.tryParse(_qtyController.text.trim());
    return parsed == null || parsed < 1 ? 1 : parsed;
  }

  String get _underlying => widget.contract.tradeUnderlying;

  int _lotSize() =>
      optionLotSize(_underlying, widget.chainContext.assetClass);

  double _orderInrEstimate(int lots) {
    final lot = _lotSize();
    final premium = widget.contract.ltp;
    final total = premium * lots * lot;
    const usdSettled = {'commodity', 'crypto', 'forex'};
    if (usdSettled.contains(widget.chainContext.assetClass)) {
      return total * 83.5;
    }
    return total;
  }

  void _setQty(int qty, int maxLots) {
    final clamped = qty.clamp(1, maxLots > 0 ? maxLots : 999);
    _qtyController.text = '$clamped';
    setState(() {});
  }

  Future<void> _placeOrder() async {
    if (_isPlacing) return;
    final trading = context.read<OptionTradingProvider>();
    final available = trading.holdingLots(
      underlying: _underlying,
      strike: widget.contract.strike,
      optionType: widget.contract.type,
      expiry: widget.contract.expiry,
      assetClass: widget.chainContext.assetClass,
    );

    if (_isSell && available < 1) {
      _snack('You don\'t hold this contract. Switch to Buy.');
      return;
    }
    if (_isSell && _qty > available) {
      _snack('You can sell at most $available lot(s).');
      return;
    }

    final wallet = context.read<WalletProvider>();
    final orderInr = _orderInrEstimate(_qty);
    if (!_isSell &&
        (!_scalper.enabled || _scalper.orderType == 'market') &&
        wallet.practiceBalance < orderInr) {
      _snack('Insufficient practice funds for this order.');
      return;
    }

    setState(() => _isPlacing = true);
    if (_scalper.enabled) {
      final order = await trading.placeScalperOrder(
        underlying: _underlying,
        strike: widget.contract.strike,
        optionType: widget.contract.type,
        expiry: widget.contract.expiry,
        side: _side,
        quantity: _qty,
        premium: widget.contract.ltp,
        assetClass: widget.chainContext.assetClass,
        orderType: _scalper.orderType,
        limitPrice: _scalper.limitPrice,
        stopLoss: _isSell ? null : _scalper.stopLoss,
        targetPrice: _isSell ? null : _scalper.targetPrice,
        trailingStopPercent: _isSell ? null : _scalper.trailingStopPercent,
      );
      if (!mounted) return;
      setState(() => _isPlacing = false);
      if (order == null) {
        _snack(trading.tradeError ?? 'Scalper order failed.');
        return;
      }
      unawaited(wallet.loadData());
      final pending = order['status'] == 'pending';
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            pending
                ? 'Option limit order placed.'
                : 'Option scalper position active.',
          ),
        ),
      );
      return;
    }
    final trade = await trading.placeOrder(
      underlying: _underlying,
      strike: widget.contract.strike,
      optionType: widget.contract.type,
      expiry: widget.contract.expiry,
      side: _side,
      quantity: _qty,
      premium: widget.contract.ltp,
      assetClass: widget.chainContext.assetClass,
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);

    if (trade == null) {
      _snack(trading.tradeError ?? 'Order failed. Try again.');
      return;
    }

    unawaited(wallet.loadData());
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await OptionOrderSuccessSheet.show(
      context,
      trade,
      currencySymbol: widget.chainContext.currencySymbol,
    );
  }

  Future<void> _exitAll(int quantity) async {
    if (_isPlacing || quantity < 1) return;
    setState(() => _isPlacing = true);
    final trading = context.read<OptionTradingProvider>();
    final order = await trading.placeScalperOrder(
      underlying: _underlying,
      strike: widget.contract.strike,
      optionType: widget.contract.type,
      expiry: widget.contract.expiry,
      side: 'SELL',
      quantity: quantity,
      premium: widget.contract.ltp,
      assetClass: widget.chainContext.assetClass,
      orderType: 'market',
    );
    if (!mounted) return;
    setState(() => _isPlacing = false);
    if (order == null) {
      _snack(trading.tradeError ?? 'Exit failed.');
      return;
    }
    unawaited(context.read<WalletProvider>().loadData());
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context, rootNavigator: true).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Option position exited successfully.')),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final screenH = MediaQuery.sizeOf(context).height;
    final contract = widget.contract;
    final lot = _lotSize();
    final isCall = contract.type == 'CE';
    final typeColor = isCall ? AppColors.green : AppColors.red;

    return Consumer2<OptionTradingProvider, WalletProvider>(
      builder: (context, trading, wallet, _) {
        final available = trading.holdingLots(
          underlying: _underlying,
          strike: contract.strike,
          optionType: contract.type,
          expiry: contract.expiry,
          assetClass: widget.chainContext.assetClass,
        );
        final canSell = available >= 1;
        final orderInr = _orderInrEstimate(_qty);
        final title = optionContractTitle(contract);

        return Container(
          height: screenH * 0.88,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ExpiryHighlight.fromDateTime(
                                contract.expiry,
                                style: ExpiryHighlightStyle.chip,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Lot $lot',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SideButton(
                        label: 'BUY',
                        selected: !_isSell,
                        color: AppColors.green,
                        onTap: () => setState(() => _side = 'BUY'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SideButton(
                        label: 'SELL',
                        selected: _isSell,
                        color: AppColors.red,
                        enabled: canSell,
                        onTap: canSell
                            ? () => setState(() => _side = 'SELL')
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Premium (LTP)',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${widget.chainContext.currencySymbol}${contract.ltp.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: typeColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              contract.type,
                              style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (available > 0) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: AppDecorations.card(context),
                        child: Text(
                          'Your position: $available lot(s)',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Lots',
                      style: TextStyle(
                        color: colors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _QtyStepButton(
                          icon: Icons.remove,
                          onTap: () => _setQty(_qty - 1, available),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        _QtyStepButton(
                          icon: Icons.add,
                          onTap: () => _setQty(_qty + 1, available),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final chip in [1, 2, 5])
                          ActionChip(
                            label: Text('$chip'),
                            onPressed: () => _setQty(chip, available),
                          ),
                        if (_isSell && available > 1)
                          ActionChip(
                            label: const Text('Max'),
                            onPressed: () => _setQty(available, available),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ScalperControls(
                      referencePrice: contract.ltp,
                      onChanged: (config) => setState(() => _scalper = config),
                    ),
                    if (_scalper.enabled && available > 0) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isPlacing
                              ? null
                              : () => _exitAll(available),
                          icon: const Icon(Icons.flash_off_rounded),
                          label: Text('One-tap exit all $available lot(s)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.red,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: AppDecorations.card(context),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: _isSell ? 'Est. credit' : 'Order value',
                            value: CurrencyFormatter.formatDecimal(orderInr),
                            bold: true,
                          ),
                          const SizedBox(height: 8),
                          _SummaryRow(
                            label: 'Practice funds',
                            value: CurrencyFormatter.formatDecimal(
                              wallet.practiceBalance,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _isPlacing ? null : _placeOrder,
                      style: FilledButton.styleFrom(
                        backgroundColor: _isSell
                            ? AppColors.red
                            : AppColors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isPlacing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isSell
                                  ? 'Sell ${contract.type}'
                                  : 'Buy ${contract.type}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SideButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback? onTap;
  final bool enabled;

  const _SideButton({
    required this.label,
    required this.selected,
    required this.color,
    this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    return Material(
      color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color : Colors.grey.shade400,
              width: active ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: enabled
                  ? (active ? color : Colors.grey.shade600)
                  : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }
}

class _QtyStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(onPressed: onTap, icon: Icon(icon));
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            fontSize: bold ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
