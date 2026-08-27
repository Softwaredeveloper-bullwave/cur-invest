import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/page_hero_background.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../../models/crypto_models.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/alt_market_shortcuts.dart';
import '../widgets/crypto_coin_tile.dart';
import '../widgets/market_switcher.dart';
import '../../../stocks/presentation/widgets/markets_news_section.dart';

class CryptoHomeScreen extends StatefulWidget {
  const CryptoHomeScreen({
    super.key,
    this.embedded = false,
    this.hubMode = false,
  });

  final bool embedded;
  final bool hubMode;

  @override
  State<CryptoHomeScreen> createState() => _CryptoHomeScreenState();
}

class _CryptoHomeScreenState extends State<CryptoHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CryptoMarketProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CryptoMarketProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.assets.isEmpty) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 5),
            ),
          );
        }

        final overview = provider.overview;
        final portfolio = provider.portfolio;
        final userName = context.watch<AuthProvider>().user?.displayName;

        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: provider.refreshAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: PageHeroBackground(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ShellPageHeader(
                                title: widget.hubMode ? 'Crypto Markets' : 'Crypto',
                                subtitle: '${GreetingHelper.getGreeting()}${userName != null && userName.isNotEmpty ? ', $userName' : ''}',
                              ),
                            ),
                            const MarketSwitcher(compact: true),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _PaperBanner(),
                        if (provider.error != null) ...[
                          const SizedBox(height: 12),
                          PremiumAlertBanner(
                            message: provider.error!,
                            type: PremiumAlertType.warning,
                            actionLabel: 'Retry',
                            onAction: provider.refreshAll,
                          ),
                        ],
                        const SizedBox(height: 16),
                        _PortfolioCard(
                          value: portfolio?.totalPortfolioValue ?? 0,
                          pnl: portfolio?.profitLoss ?? 0,
                          pnlPct: portfolio?.profitLossPercent ?? 0,
                        ),
                        if (overview != null) ...[
                          const SizedBox(height: 16),
                          _OverviewStats(overview: overview),
                        ],
                        const SizedBox(height: 16),
                        const ScrollReveal(
                          child: AltMarketShortcuts(kind: AltMarketKind.crypto),
                        ),
                      ],
                    ),
                  ),
                ),
                if (overview != null && overview.trending.isNotEmpty)
                  SliverToBoxAdapter(
                    child: ScrollReveal(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Row(
                          children: [
                            Text('Trending', style: context.typeSection(16)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.cryptoMovers),
                              child: const Text('See movers'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (overview != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => CryptoCoinTile(asset: overview.trending[index]),
                      childCount: overview.trending.length.clamp(0, 5),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: ScrollReveal(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Top coins', style: context.typeSection(16)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.cryptoSearch),
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => CryptoCoinTile(asset: provider.assets[index]),
                    childCount: provider.assets.length.clamp(0, 15),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverToBoxAdapter(
                  child: ScrollReveal(
                    child: MarketsNewsSection(
                      news: provider.news
                          .take(4)
                          .map(
                            (n) => <String, String>{
                              'title': n.title,
                              'time': n.source,
                              'category': n.category.isEmpty ? 'Crypto' : n.category,
                              'imageUrl': n.imageUrl,
                              'url': n.externalUrl,
                            },
                          )
                          .toList(),
                      seeAllRoute: AppRoutes.cryptoNews,
                      useFallback: false,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PaperBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.primaryBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: p.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'PAPER TRADING — Virtual funds only. No real crypto execution.',
              style: context.typeLabel(12, p.primaryDark).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({
    required this.value,
    required this.pnl,
    required this.pnlPct,
  });

  final double value;
  final double pnl;
  final double pnlPct;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final positive = pnl >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: p.heroCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Portfolio value', style: context.typeLabel(12, p.heroCardMuted)),
          const SizedBox(height: 6),
          Text(
            CurrencyFormatter.formatCompact(value),
            style: context.typeHeading.copyWith(fontSize: 26, color: p.heroCardFg),
          ),
          const SizedBox(height: 8),
          Text(
            '${IndexFormatter.formatPercent(pnlPct)} · ${CurrencyFormatter.formatDecimal(pnl.abs())} ${positive ? 'gain' : 'loss'}',
            style: context.typeLabel(13, positive ? p.positive : p.negative),
          ),
        ],
      ),
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({required this.overview});

  final CryptoOverviewModel overview;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'BTC dominance',
            value: '${overview.btcDominance.toStringAsFixed(1)}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Fear & Greed',
            value: overview.fearGreedValue > 0
                ? '${overview.fearGreedValue}'
                : '—',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: '24h mcap',
            value: IndexFormatter.formatPercent(overview.marketCapChange24h),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: p.card.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.typeSecondary(11), maxLines: 1),
          const SizedBox(height: 4),
          Text(value, style: context.typeCardTitle(13)),
        ],
      ),
    );
  }
}
