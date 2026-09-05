import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/dual_pnl_label.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../../models/crypto_models.dart';
import '../../../../models/forex_models.dart';
import '../../../../models/option_trade_model.dart';
import '../../../../models/stock_model.dart';
import '../../../crypto/presentation/provider/crypto_market_provider.dart';
import '../../../forex/presentation/provider/forex_market_provider.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../../../stocks/presentation/provider/option_trading_provider.dart';
import '../../../stocks/presentation/provider/stock_features_provider.dart';
import '../../../stocks/presentation/provider/stock_portfolio_provider.dart';

enum HomeOpenTradesMarket { indian, crypto, forex }

class HomeOpenTradesSection extends StatefulWidget {
  const HomeOpenTradesSection({super.key, required this.market});

  final HomeOpenTradesMarket market;

  @override
  State<HomeOpenTradesSection> createState() => _HomeOpenTradesSectionState();
}

class _HomeOpenTradesSectionState extends State<HomeOpenTradesSection> {
  String? _exitingId;
  Timer? _liveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    _liveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_refresh());
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    final options = context.read<OptionTradingProvider>();
    switch (widget.market) {
      case HomeOpenTradesMarket.indian:
        unawaited(
          context.read<StockPortfolioProvider>().ensureLoaded(
            refreshQuotes: true,
          ),
        );
        unawaited(options.loadHoldings(assetClass: 'equity_fno'));
      case HomeOpenTradesMarket.crypto:
        unawaited(context.read<CryptoMarketProvider>().refreshPortfolio());
        unawaited(options.loadHoldings(assetClass: 'crypto'));
      case HomeOpenTradesMarket.forex:
        unawaited(context.read<ForexMarketProvider>().loadPortfolio());
        unawaited(options.loadHoldings(assetClass: 'forex'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.market) {
      HomeOpenTradesMarket.indian => Consumer2<StockPortfolioProvider,
          OptionTradingProvider>(
        builder: (context, stocks, options, _) {
          return _list(
            context,
            [
              for (final h in stocks.holdings.where((h) => h.quantity > 0))
                _itemFromStock(h),
              for (final h in options.holdingsFor('equity_fno'))
                _itemFromOption(h, dual: false, usdInr: 83.5),
            ],
          );
        },
      ),
      HomeOpenTradesMarket.crypto => Consumer2<CryptoMarketProvider,
          OptionTradingProvider>(
        builder: (context, crypto, options, _) {
          final rate = crypto.portfolio?.usdInrRate ?? 83.5;
          return _list(
            context,
            [
              for (final h
                  in (crypto.portfolio?.holdings ?? const <CryptoHoldingModel>[])
                      .where((h) => h.quantity > 0))
                _itemFromCrypto(h, rate),
              for (final h in options.holdingsFor('crypto'))
                _itemFromOption(h, dual: true, usdInr: rate),
            ],
          );
        },
      ),
      HomeOpenTradesMarket.forex => Consumer2<ForexMarketProvider,
          OptionTradingProvider>(
        builder: (context, forex, options, _) {
          final rate = forex.portfolio?.usdInrRate ?? 83.5;
          return _list(
            context,
            [
              for (final h
                  in (forex.portfolio?.holdings ?? const <ForexHoldingModel>[])
                      .where((h) => h.quantity > 0))
                _itemFromForex(h, rate),
              for (final h in options.holdingsFor('forex'))
                _itemFromOption(h, dual: true, usdInr: rate),
            ],
          );
        },
      ),
    };
  }

  Widget _list(BuildContext context, List<_OpenTradeItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    return ScrollReveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Your trades', style: context.typeSection(16)),
                const Spacer(),
                Text(
                  '${items.length} open',
                  style: context.typeMuted(12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Live P&L · tap Exit to close the full paper position',
              style: context.typeMuted(11),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: item.onOpen,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                      decoration: p.cardDecoration(radius: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: context.typeCardTitle(15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: context.typeMuted(12),
                                ),
                                if (item.kindLabel != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.kindLabel!,
                                    style: context.typeLabel(10, p.textMuted),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          DualPnlLabel(
                            pnlInr: item.pnlInr,
                            percent: item.pnlPercent,
                            usdInr: item.usdInr,
                            showUsd: item.dualCurrency,
                            compact: true,
                          ),
                          const SizedBox(width: 8),
                          _ExitButton(
                            busy: _exitingId == item.id,
                            onPressed: _exitingId != null
                                ? null
                                : () => _confirmExit(item),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  _OpenTradeItem _itemFromStock(StockHoldingModel h) {
    return _OpenTradeItem(
      id: 'stock:${h.symbol}',
      title: h.symbol,
      subtitle:
          '${h.quantity} shares @ ${CurrencyFormatter.formatDecimal(h.avgPrice)}',
      pnlInr: h.pnl,
      pnlPercent: h.pnlPercent,
      dualCurrency: false,
      onOpen: () =>
          context.push('${AppRoutes.stockDetail}?symbol=${h.symbol}'),
      onExit: () => _exitStock(h),
    );
  }

  _OpenTradeItem _itemFromCrypto(CryptoHoldingModel h, double rate) {
    return _OpenTradeItem(
      id: 'crypto:${h.assetId}',
      title: h.symbol,
      subtitle:
          '${_qtyLabel(h.quantity)} @ ${CurrencyFormatter.formatLedger(h.avgPrice, market: 'crypto', usdInr: rate, decimals: true)}',
      pnlInr: h.unrealizedPnl,
      pnlPercent: h.unrealizedPnlPercent,
      dualCurrency: true,
      usdInr: rate,
      onOpen: () => context.push(AppRoutes.cryptoDetailPath(h.assetId)),
      onExit: () => _exitCrypto(h),
    );
  }

  _OpenTradeItem _itemFromForex(ForexHoldingModel h, double rate) {
    final invested = h.quantity * h.avgPrice;
    final pct = invested == 0 ? 0.0 : (h.profitLoss / invested) * 100;
    return _OpenTradeItem(
      id: 'forex:${h.pairId}',
      title: h.symbol,
      subtitle:
          'Qty ${_qtyLabel(h.quantity)} @ ${IndexFormatter.format(h.avgPrice)}',
      pnlInr: h.profitLoss,
      pnlPercent: pct,
      dualCurrency: true,
      usdInr: rate,
      onOpen: () => context.push(AppRoutes.forexDetailPath(h.pairId)),
      onExit: () => _exitForex(h),
    );
  }

  _OpenTradeItem _itemFromOption(
    OptionHoldingModel h, {
    required bool dual,
    required double usdInr,
  }) {
    final cost = h.avgPremium * h.quantity * (h.lotSize <= 0 ? 1 : h.lotSize);
    final costInr = dual ? cost * usdInr : cost;
    return _OpenTradeItem(
      id:
          'opt:${h.assetClass}:${h.underlying}:${h.optionType}:${h.strike}:${h.expiry.toIso8601String()}',
      title: h.contractLabel.isNotEmpty
          ? h.contractLabel
          : '${h.underlying} ${h.strike} ${h.optionType}',
      subtitle:
          '${h.quantity} lot(s) @ ${dual ? CurrencyFormatter.formatUsd(h.avgPremium) : CurrencyFormatter.formatDecimal(h.avgPremium)}',
      pnlInr: 0,
      dualCurrency: dual,
      usdInr: usdInr,
      kindLabel: 'Cost ${dual ? CurrencyFormatter.formatSignedUsd(costInr, usdInr) : CurrencyFormatter.formatDecimal(costInr)} · P&L at market on exit',
      onExit: () => _exitOption(h),
    );
  }

  Future<void> _confirmExit(_OpenTradeItem item) async {
    final ok = await CustomDialog.showConfirm(
      context,
      title: 'Exit ${item.title}?',
      message:
          'This sells your full paper position at the current market price.',
      confirmLabel: 'Exit',
      cancelLabel: 'Keep',
    );
    if (ok != true || !mounted) return;
    setState(() => _exitingId = item.id);
    final error = await item.onExit();
    if (!mounted) return;
    setState(() => _exitingId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Position exited.'),
        backgroundColor: error == null ? AppColors.green : AppColors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _exitStock(StockHoldingModel h) async {
    final features = context.read<StockFeaturesProvider>();
    final portfolio = context.read<StockPortfolioProvider>();
    final wallet = context.read<WalletProvider>();
    final order = await features.placePaperTrade(
      symbol: h.symbol,
      side: 'SELL',
      qty: h.quantity,
    );
    if (order == null) {
      return features.tradeError ?? 'Could not exit this stock.';
    }
    portfolio.applyExecutedOrder(order);
    unawaited(portfolio.loadPortfolio());
    unawaited(wallet.loadData());
    return null;
  }

  Future<String?> _exitCrypto(CryptoHoldingModel h) async {
    final provider = context.read<CryptoMarketProvider>();
    final result = await provider.placePaperOrder(
      assetId: h.assetId,
      side: 'SELL',
      quantity: h.quantity,
    );
    if (result == null) {
      return provider.error ?? 'Could not exit this crypto position.';
    }
    return null;
  }

  Future<String?> _exitForex(ForexHoldingModel h) async {
    final provider = context.read<ForexMarketProvider>();
    final result = await provider.placePaperOrder(
      pairId: h.pairId,
      side: 'SELL',
      quantity: h.quantity,
    );
    if (result == null) {
      return provider.error ?? 'Could not exit this forex position.';
    }
    return null;
  }

  Future<String?> _exitOption(OptionHoldingModel h) async {
    final trading = context.read<OptionTradingProvider>();
    final wallet = context.read<WalletProvider>();
    final trade = await trading.placeOrder(
      underlying: h.underlying,
      strike: h.strike,
      optionType: h.optionType,
      expiry: h.expiry,
      side: 'SELL',
      quantity: h.quantity,
      premium: h.avgPremium > 0 ? h.avgPremium : 0.01,
      assetClass: h.assetClass,
    );
    if (trade == null) {
      return trading.tradeError ?? 'Could not exit this option.';
    }
    unawaited(wallet.loadData());
    return null;
  }

  String _qtyLabel(double qty) {
    if (qty >= 1) {
      return qty == qty.roundToDouble()
          ? qty.toStringAsFixed(0)
          : qty.toStringAsFixed(4);
    }
    return qty.toStringAsFixed(6);
  }
}

class _OpenTradeItem {
  const _OpenTradeItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.pnlInr,
    required this.onExit,
    this.pnlPercent,
    this.dualCurrency = false,
    this.usdInr = 83.5,
    this.kindLabel,
    this.onOpen,
  });

  final String id;
  final String title;
  final String subtitle;
  final double pnlInr;
  final double? pnlPercent;
  final bool dualCurrency;
  final double usdInr;
  final String? kindLabel;
  final VoidCallback? onOpen;
  final Future<String?> Function() onExit;
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(56, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Exit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
      ),
    );
  }
}
