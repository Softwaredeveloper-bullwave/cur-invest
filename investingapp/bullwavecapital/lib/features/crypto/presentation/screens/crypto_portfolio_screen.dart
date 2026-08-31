import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/page_hero_background.dart';
import '../../../../core/widgets/paper_trading_disclaimer.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../../models/crypto_models.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/alt_market_shortcuts.dart';
import '../widgets/market_switcher.dart';

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

        final holdings = portfolio?.holdings ?? const [];
        return RefreshIndicator(
          color: AppColors.brandCyan,
          onRefresh: provider.refreshPortfolio,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              PageHeroBackground(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: ShellPageHeader(
                            title: 'Crypto Portfolio',
                            subtitle: 'Paper wallet · virtual crypto holdings',
                          ),
                        ),
                        if (widget.embedded) const MarketSwitcher(compact: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const PaperTradingDisclaimer(compact: true),
                    const SizedBox(height: 16),
                    if (portfolio != null) _SummaryCard(portfolio: portfolio),
                    const SizedBox(height: 18),
                    const ScrollReveal(
                      child: AltMarketShortcuts(kind: AltMarketKind.crypto),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: ScrollReveal(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Holdings', style: context.typeSection(16)),
                    const SizedBox(height: 10),
                    if (holdings.isEmpty)
                      AltMarketEmptyHoldings(
                        title: 'No crypto holdings yet',
                        subtitle:
                            'Place a paper buy from any coin on Markets to build this book.',
                        ctaLabel: 'Open Markets',
                        onCta: () => context.go(AppRoutes.invest),
                      )
                    else
                      ...holdings.map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () =>
                                  context.push(AppRoutes.cryptoDetailPath(h.assetId)),
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
                                            '${h.quantity.toStringAsFixed(4)} @ ${CurrencyFormatter.formatLedger(h.avgPrice, market: 'crypto', usdInr: portfolio?.usdInrRate, decimals: true)}',
                                            style: context.typeMuted(12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyFormatter.formatLedger(
                                            h.currentValue,
                                            market: 'crypto',
                                            usdInr: portfolio?.usdInrRate,
                                            decimals: true,
                                          ),
                                          style: context.typeCardTitle(14),
                                        ),
                                        Text(
                                          IndexFormatter.formatPercent(h.unrealizedPnlPercent),
                                          style: context.typeLabel(
                                            12,
                                            h.isPositive
                                                ? context.palette.positive
                                                : context.palette.negative,
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
                    const AltMarketBottomSpacer(),
                  ],
                ),
                ),
              ),
            ],
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
            CurrencyFormatter.formatLedger(
              portfolio.totalPortfolioValue,
              market: 'crypto',
              usdInr: portfolio.usdInrRate,
              compact: true,
            ),
            style: context.typeHeading.copyWith(fontSize: 26, color: p.heroCardFg),
          ),
          const SizedBox(height: 4),
          Text(
            'USD · converted from paper INR',
            style: context.typeLabel(11, p.heroCardMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Cash ${CurrencyFormatter.formatLedger(portfolio.walletBalance, market: 'crypto', usdInr: portfolio.usdInrRate, decimals: true)} · P&L ${IndexFormatter.formatPercent(portfolio.profitLossPercent)}',
            style: context.typeLabel(13, p.heroCardMuted),
          ),
        ],
      ),
    );
  }
}
