import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/dual_pnl_label.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/page_hero_background.dart';
import '../../../../core/widgets/paper_trading_disclaimer.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../crypto/presentation/widgets/alt_market_shortcuts.dart';
import '../../../crypto/presentation/widgets/market_switcher.dart';
import '../provider/forex_market_provider.dart';

class ForexPortfolioScreen extends StatefulWidget {
  const ForexPortfolioScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<ForexPortfolioScreen> createState() => _ForexPortfolioScreenState();
}

class _ForexPortfolioScreenState extends State<ForexPortfolioScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ForexMarketProvider>();
      provider.ensureLoaded();
      provider.loadPortfolio();
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = Consumer<ForexMarketProvider>(
      builder: (context, provider, _) {
        final portfolio = provider.portfolio;
        final holdings = portfolio?.holdings ?? const [];
        final p = context.palette;
        return RefreshIndicator(
          color: AppColors.brandCyan,
          onRefresh: () async {
            await provider.loadPortfolio();
            await provider.ensureLoaded();
          },
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
                            title: 'Forex Portfolio',
                            subtitle: 'Paper wallet · virtual FX positions',
                          ),
                        ),
                        if (widget.embedded) const MarketSwitcher(compact: true),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const PaperTradingDisclaimer(compact: true),
                    const SizedBox(height: 16),
                    _SummaryCard(
                      wallet: portfolio?.walletBalance ?? 0,
                      invested: portfolio?.investedAmount ?? 0,
                      value: portfolio?.totalPortfolioValue ??
                          portfolio?.walletBalance ??
                          0,
                      pnl: portfolio?.profitLoss ?? 0,
                      pnlPct: portfolio?.profitLossPercent ?? 0,
                      usdInrRate: portfolio?.usdInrRate ?? 83.5,
                    ),
                    const SizedBox(height: 18),
                    const ScrollReveal(
                      child: AltMarketShortcuts(kind: AltMarketKind.forex),
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
                        title: 'No forex positions yet',
                        subtitle:
                            'Paper-buy a major pair from Markets to start this portfolio.',
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
                              onTap: () => context.push(AppRoutes.forexDetailPath(h.pairId)),
                              borderRadius: BorderRadius.circular(18),
                              child: Ink(
                                padding: const EdgeInsets.all(14),
                                decoration: p.cardDecoration(radius: 18),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(h.symbol, style: context.typeCardTitle(15)),
                                          if (h.name.isNotEmpty)
                                            Text(h.name, style: context.typeSecondary(13)),
                                          Text(
                                            'Qty ${h.quantity} @ ${IndexFormatter.format(h.avgPrice)}',
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
                                            market: 'forex',
                                            usdInr: portfolio?.usdInrRate,
                                            compact: true,
                                          ),
                                          style: context.typeCardTitle(14),
                                        ),
                                        DualPnlLabel(
                                          pnlInr: h.profitLoss,
                                          usdInr: portfolio?.usdInrRate,
                                          showUsd: true,
                                          compact: true,
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
      appBar: const CustomAppBar(title: 'Forex Portfolio'),
      body: body,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.wallet,
    required this.invested,
    required this.value,
    required this.pnl,
    required this.pnlPct,
    required this.usdInrRate,
  });

  final double wallet;
  final double invested;
  final double value;
  final double pnl;
  final double pnlPct;
  final double usdInrRate;

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
          Text('Paper wallet', style: context.typeLabel(12, p.heroCardMuted)),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatLedger(
              value,
              market: 'forex',
              usdInr: usdInrRate,
              compact: true,
            ),
            style: context.typeHeading.copyWith(fontSize: 28, color: p.heroCardFg),
          ),
          const SizedBox(height: 4),
          Text(
            'USD · converted from paper INR',
            style: context.typeLabel(11, p.heroCardMuted),
          ),
          const SizedBox(height: 8),
          Text(
            'Cash ${CurrencyFormatter.formatLedger(wallet, market: 'forex', usdInr: usdInrRate, compact: true)} · Invested ${CurrencyFormatter.formatLedger(invested, market: 'forex', usdInr: usdInrRate, compact: true)}',
            style: context.typeLabel(13, p.heroCardMuted),
          ),
          const SizedBox(height: 8),
          DualPnlLabel(
            pnlInr: pnl,
            percent: pnlPct,
            usdInr: usdInrRate,
            showUsd: true,
            alignEnd: false,
          ),
        ],
      ),
    );
  }
}
