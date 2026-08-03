import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/stock_model.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/paper_competition_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_market_provider.dart';
import '../utils/stock_trading_flow.dart';
import '../widgets/paper_competition_widgets.dart';
import '../widgets/stock_order_history_tile.dart';

/// Shell tab routes must use [GoRouter.go]; root routes use [GoRouter.push].
void _openPaperHubLink(BuildContext context, String route) {
  final path = Uri.parse(route).path;
  const shellTabPaths = {
    AppRoutes.home,
    AppRoutes.invest,
    AppRoutes.portfolio,
    AppRoutes.wallet,
    AppRoutes.profile,
  };
  if (shellTabPaths.contains(path)) {
    context.go(path);
    return;
  }
  context.push(route);
}

class PaperTradingScreen extends StatefulWidget {
  const PaperTradingScreen({super.key});

  @override
  State<PaperTradingScreen> createState() => _PaperTradingScreenState();
}

class _PaperTradingScreenState extends State<PaperTradingScreen> {
  final _symbolController = TextEditingController(text: 'RELIANCE');
  final _qtyController = TextEditingController(text: '1');
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final market = context.read<StockMarketProvider>();
      final features = context.read<StockFeaturesProvider>();
      final paperExtras = context.read<PaperCompetitionProvider>();
      final wallet = context.read<WalletProvider>();
      await market.ensureLoaded();
      await Future.wait([
        features.refreshPaperTrades(),
        features.refreshScalperOrders(),
        paperExtras.refresh(),
        wallet.loadData(),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not refresh paper trading data. Pull to retry.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _place(String side) async {
    final symbol = _symbolController.text.trim().toUpperCase();
    final stock = context.read<StockMarketProvider>().getStock(symbol);
    if (stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unknown symbol. Pick a stock from Markets first.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    await executeStockTrade(context, stock: stock, side: side);
    if (!mounted) return;
    await Future.wait([
      context.read<StockFeaturesProvider>().refreshPaperTrades(),
      context.read<PaperCompetitionProvider>().refresh(),
      context.read<WalletProvider>().loadData(),
    ]);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper Trading'),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: LoadingList(itemCount: 4, itemHeight: 64),
              ),
            )
          : RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child:
                  Consumer3<
                    StockFeaturesProvider,
                    StockMarketProvider,
                    PaperCompetitionProvider
                  >(
                    builder: (context, features, market, paperExtras, _) {
                      final symbol = _symbolController.text
                          .trim()
                          .toUpperCase();
                      final stock = market.getStock(symbol);
                      final trades = features.paperTrades;

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _InfoBanner(colors: colors),
                          const SizedBox(height: 14),
                          _PracticeFundsCard(
                            balance: context
                                .watch<WalletProvider>()
                                .practiceBalance,
                            refillThreshold: context
                                .watch<WalletProvider>()
                                .practiceRefillThreshold,
                          ),
                          const SizedBox(height: 14),
                          _PaperFeatureGrid(
                            activeScalperOrders: features.scalperOrders
                                .where(
                                  (row) =>
                                      row['status'] == 'active' ||
                                      row['status'] == 'pending',
                                )
                                .length,
                          ),
                          const SizedBox(height: 14),
                          PaperRiskMeterCard(
                            meter: paperExtras.riskMeter,
                            isLoading: paperExtras.isLoading,
                          ),
                          const SizedBox(height: 14),
                          PaperCompetitionCard(
                            competitions: paperExtras.competitions,
                            isLoading: paperExtras.isSaving,
                            onCreate: () => showCreateCompetitionSheet(context),
                            onJoin: () => showJoinCompetitionSheet(context),
                            onOpen: (c) =>
                                showCompetitionDetailSheet(context, c),
                          ),
                          const SizedBox(height: 16),
                          _TradeForm(
                            colors: colors,
                            symbolController: _symbolController,
                            qtyController: _qtyController,
                            stock: stock,
                            isPlacing: false,
                            onSymbolChanged: () => setState(() {}),
                            onBuy: () => _place('BUY'),
                            onSell: () => _place('SELL'),
                            suggestions: market.trendingStocks
                                .take(6)
                                .map((s) => s.symbol)
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Order History',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (trades.isEmpty)
                            _EmptyHistory(colors: colors)
                          else
                            ...trades.map(
                              (t) => StockOrderHistoryTile(order: t),
                            ),
                        ],
                      );
                    },
                  ),
            ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final AppThemeExtension colors;

  const _InfoBanner({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.brandOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: AppColors.brandOrange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Practice F&O trades with virtual money — no real funds at risk.',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeFundsCard extends StatelessWidget {
  final double balance;
  final double refillThreshold;

  const _PracticeFundsCard({
    required this.balance,
    required this.refillThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: AppDecorations.card(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Practice Funds',
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.green.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Text(
                        'VIRTUAL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.green,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(balance),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Refills to ₹1,00,000 below ${CurrencyFormatter.format(refillThreshold)}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 11, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperFeatureGrid extends StatelessWidget {
  final int activeScalperOrders;

  const _PaperFeatureGrid({required this.activeScalperOrders});

  static const _tileHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 820 ? 4 : (width >= 560 ? 3 : 2);

    final items = [
      (
        'Stocks',
        Icons.candlestick_chart_outlined,
        AppColors.blue,
        AppRoutes.invest,
      ),
      (
        'Futures',
        Icons.timeline_rounded,
        AppColors.brandOrange,
        '${AppRoutes.indexFnoHub}?symbol=NIFTY&paper=1',
      ),
      (
        'Options',
        Icons.account_tree_outlined,
        AppColors.brandPurple,
        '${AppRoutes.optionChain}?symbol=NIFTY&paper=1',
      ),
      (
        'Commodities',
        Icons.oil_barrel_outlined,
        AppColors.warningAmber,
        AppRoutes.commodities,
      ),
      (
        'TradingView',
        Icons.show_chart_rounded,
        AppColors.green,
        '${AppRoutes.stockDetail}?symbol=RELIANCE',
      ),
      (
        'Portfolio',
        Icons.pie_chart_outline_rounded,
        AppColors.blue,
        AppRoutes.paperPortfolio,
      ),
      (
        'Scalper${activeScalperOrders > 0 ? ' ($activeScalperOrders)' : ''}',
        Icons.bolt_rounded,
        AppColors.red,
        '${AppRoutes.stockDetail}?symbol=RELIANCE',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Every Market',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a market to practice with virtual funds.',
          style: TextStyle(color: colors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: _tileHeight,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _PaperMarketTile(
              label: item.$1,
              icon: item.$2,
              color: item.$3,
              onTap: () => _openPaperHubLink(context, item.$4),
            );
          },
        ),
      ],
    );
  }
}

class _PaperMarketTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PaperMarketTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          decoration: AppDecorations.card(context).copyWith(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 16, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _TradeForm extends StatelessWidget {
  final AppThemeExtension colors;
  final TextEditingController symbolController;
  final TextEditingController qtyController;
  final StockModel? stock;
  final bool isPlacing;
  final VoidCallback onSymbolChanged;
  final VoidCallback onBuy;
  final VoidCallback onSell;
  final List<String> suggestions;

  const _TradeForm({
    required this.colors,
    required this.symbolController,
    required this.qtyController,
    required this.stock,
    required this.isPlacing,
    required this.onSymbolChanged,
    required this.onBuy,
    required this.onSell,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Place Order',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: symbolController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Symbol',
              hintText: 'e.g. RELIANCE',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (_) => onSymbolChanged(),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((s) {
              return ActionChip(
                label: Text(
                  s,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () {
                  symbolController.text = s;
                  onSymbolChanged();
                },
              );
            }).toList(),
          ),
          if (stock != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'LTP ',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                Text(
                  IndexFormatter.format(stock!.ltp),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  IndexFormatter.formatPercent(stock!.changePercent),
                  style: TextStyle(
                    color: stock!.isPositive ? AppColors.green : AppColors.red,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity (lots)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: isPlacing ? null : onBuy,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isPlacing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Buy',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: isPlacing ? null : onSell,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: BorderSide(
                        color: AppColors.red.withValues(alpha: 0.7),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sell',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final AppThemeExtension colors;

  const _EmptyHistory({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 44, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No paper trades yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Place a buy or sell order above to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
