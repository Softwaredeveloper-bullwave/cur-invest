import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../models/crypto_models.dart';
import '../provider/crypto_market_provider.dart';

class CryptoPortfolioScreen extends StatefulWidget {
  const CryptoPortfolioScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<CryptoPortfolioScreen> createState() => _CryptoPortfolioScreenState();
}

class _CryptoPortfolioScreenState extends State<CryptoPortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CryptoMarketProvider>().refreshPortfolio();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<CryptoMarketProvider>(
      builder: (context, provider, _) {
        final portfolio = provider.portfolio;
        if (provider.isLoading && portfolio == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LoadingList(itemCount: 4),
          );
        }
        if (portfolio == null) {
          return Center(
            child: Text(
              provider.error ?? 'Market data is temporarily unavailable. Please try again.',
              style: context.typeSecondary(14),
              textAlign: TextAlign.center,
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.brandCyan,
          onRefresh: provider.refreshPortfolio,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaperBanner(),
                const SizedBox(height: 16),
                _SummaryCard(portfolio: portfolio),
                const SizedBox(height: 20),
                Text('Holdings', style: context.typeSection(16)),
                const SizedBox(height: 8),
                if (portfolio.holdings.isEmpty)
                  Text(
                    'No crypto holdings yet. Place a PAPER TRADING order from any coin.',
                    style: context.typeSecondary(14),
                  )
                else
                  ...portfolio.holdings.map(
                    (h) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => context.push(AppRoutes.cryptoDetailPath(h.assetId)),
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: context.palette.cardDecoration(radius: 18),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(h.symbol, style: context.typeCardTitle(15)),
                                      Text(h.name, style: context.typeSecondary(13)),
                                      Text(
                                        '${h.quantity.toStringAsFixed(4)} @ ${CurrencyFormatter.formatDecimal(h.avgPrice)}',
                                        style: context.typeMuted(12),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.formatDecimal(h.currentValue),
                                      style: context.typeCardTitle(14),
                                    ),
                                    Text(
                                      IndexFormatter.formatPercent(h.unrealizedPnlPercent),
                                      style: context.typeLabel(
                                        12,
                                        h.isPositive ? context.palette.positive : context.palette.negative,
                                      ),
                                    ),
                                  ],
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
      },
    );

    if (widget.embedded) return SafeArea(child: body);
    return Scaffold(
      appBar: const CustomAppBar(title: 'Crypto Portfolio'),
      body: body,
    );
  }
}

class _PaperBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.primaryBorder),
      ),
      child: Text(
        'PAPER TRADING — Virtual portfolio. No real crypto assets.',
        style: context.typeLabel(12, p.primaryDark).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.portfolio});

  final CryptoPortfolioModel portfolio;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: p.heroCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total value', style: context.typeLabel(12, p.heroCardMuted)),
          Text(
            CurrencyFormatter.formatCompact(portfolio.totalPortfolioValue),
            style: context.typeHeading.copyWith(fontSize: 26, color: p.heroCardFg),
          ),
          const SizedBox(height: 8),
          Text(
            'Cash ${CurrencyFormatter.formatDecimal(portfolio.walletBalance)} · P&L ${IndexFormatter.formatPercent(portfolio.profitLossPercent)}',
            style: context.typeLabel(13, p.heroCardMuted),
          ),
        ],
      ),
    );
  }
}
