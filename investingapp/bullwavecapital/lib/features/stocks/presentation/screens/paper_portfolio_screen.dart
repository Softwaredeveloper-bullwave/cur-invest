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
import '../../../../core/widgets/portfolio_card.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../provider/stock_features_provider.dart';
import '../provider/stock_portfolio_provider.dart';
import '../utils/stock_trading_flow.dart';
import '../widgets/stock_order_history_tile.dart';
import '../../../portfolio/presentation/widgets/portfolio_holding_tile.dart';

/// Paper holdings shown from the Paper Trading hub (root navigator).
class PaperPortfolioScreen extends StatefulWidget {
  const PaperPortfolioScreen({super.key});

  @override
  State<PaperPortfolioScreen> createState() => _PaperPortfolioScreenState();
}

class _PaperPortfolioScreenState extends State<PaperPortfolioScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await Future.wait([
      context.read<StockPortfolioProvider>().loadPortfolio(refreshQuotes: true),
      context.read<StockFeaturesProvider>().refreshPaperTrades(),
      context.read<WalletProvider>().loadData(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const CustomAppBar(title: 'Paper Portfolio'),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: LoadingList(itemCount: 4, itemHeight: 72),
            )
          : RefreshIndicator(
              color: AppColors.brandOrange,
              onRefresh: _load,
              child:
                  Consumer3<
                    StockPortfolioProvider,
                    StockFeaturesProvider,
                    WalletProvider
                  >(
                    builder: (context, portfolio, features, wallet, _) {
                      final summary = portfolio.summary;
                      final holdings = portfolio.holdings;
                      final trades = features.paperTrades;
                      final cash = wallet.practiceBalance;
                      final equity = cash + summary.currentValue;

                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          _PracticeCashCard(balance: cash, equity: equity),
                          const SizedBox(height: 14),
                          PortfolioSummaryCard(
                            totalInvestment: summary.totalInvested,
                            currentValue: summary.currentValue,
                            totalProfit: summary.totalPnl,
                            todayPnl: summary.dayPnl,
                            todayPnlPercent: summary.dayPnlPercent,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Holdings',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (holdings.isEmpty)
                            _EmptyHoldings(colors: colors)
                          else
                            ...holdings.map(
                              (h) => PortfolioHoldingTile(
                                holding: h,
                                onTap: () => context.push(
                                  '${AppRoutes.stockDetail}?symbol=${h.symbol}',
                                ),
                                onBuy: () => executeStockTrade(
                                  context,
                                  stock: h.toTradeStock(),
                                  side: 'BUY',
                                ),
                                onSell: () => executeStockTrade(
                                  context,
                                  stock: h.toTradeStock(),
                                  side: 'SELL',
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          Text(
                            'Recent Paper Trades',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          if (trades.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 32,
                                horizontal: 20,
                              ),
                              decoration: AppDecorations.card(context),
                              child: Text(
                                'No paper trades yet. Place an order from Paper Trading.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: colors.textMuted),
                              ),
                            )
                          else
                            ...trades
                                .take(12)
                                .map((t) => StockOrderHistoryTile(order: t)),
                        ],
                      );
                    },
                  ),
            ),
    );
  }
}

class _PracticeCashCard extends StatelessWidget {
  final double balance;
  final double equity;

  const _PracticeCashCard({required this.balance, required this.equity});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Practice cash',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                Text(
                  CurrencyFormatter.format(balance),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Total equity',
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
                Text(
                  CurrencyFormatter.format(equity),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHoldings extends StatelessWidget {
  final AppThemeExtension colors;

  const _EmptyHoldings({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: AppDecorations.card(context),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 44,
            color: colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No paper holdings yet',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Buy stocks from Paper Trading to build your practice portfolio.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
