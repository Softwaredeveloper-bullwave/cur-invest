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
import '../../../crypto/presentation/widgets/alt_market_shortcuts.dart';
import '../../../crypto/presentation/widgets/market_switcher.dart';
import '../../../stocks/presentation/widgets/markets_learning_hub.dart';
import '../../../stocks/presentation/widgets/markets_news_section.dart';
import '../provider/forex_market_provider.dart';
import '../widgets/forex_pair_tile.dart';

class ForexHomeScreen extends StatefulWidget {
  const ForexHomeScreen({super.key, this.embedded = false, this.hubMode = false});

  final bool embedded;
  final bool hubMode;

  @override
  State<ForexHomeScreen> createState() => _ForexHomeScreenState();
}

class _ForexHomeScreenState extends State<ForexHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForexMarketProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ForexMarketProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.pairs.isEmpty) {
          return const SafeArea(
            child: Padding(padding: EdgeInsets.all(16), child: LoadingList(itemCount: 5)),
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
                                title: widget.hubMode ? 'Forex Markets' : 'Forex',
                                subtitle:
                                    '${GreetingHelper.getGreeting()}${userName != null && userName.isNotEmpty ? ', $userName' : ''}',
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
                        const SizedBox(height: 16),
                        const ScrollReveal(
                          child: AltMarketShortcuts(kind: AltMarketKind.forex),
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
                            Text('Movers', style: context.typeSection(16)),
                            const Spacer(),
                            TextButton(
                              onPressed: () => context.push(AppRoutes.forexMovers),
                              child: const Text('See all'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (overview != null)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ForexPairTile(pair: overview.trending[index]),
                      childCount: overview.trending.length.clamp(0, 5),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: ScrollReveal(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          Text('Major pairs', style: context.typeSection(16)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.forexSearch),
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ForexPairTile(pair: provider.pairs[index]),
                    childCount: provider.pairs.length.clamp(0, 18),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                const SliverToBoxAdapter(
                  child: ScrollReveal(
                    child: MarketsLearningHub(market: 'forex'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ScrollReveal(
                    child: MarketsNewsSection(
                      news: provider.news
                          .take(4)
                          .map(
                            (n) => <String, String>{
                              'title': n.title,
                              'time': n.source,
                              'category': n.category.isEmpty ? 'Forex' : n.category,
                              'imageUrl': n.imageUrl,
                              'url': n.externalUrl,
                            },
                          )
                          .toList(),
                      seeAllRoute: AppRoutes.forexNews,
                      useFallback: false,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: AltMarketBottomSpacer()),
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
              'PAPER TRADING — Virtual funds only. No live forex execution.',
              style: context.typeLabel(12, p.primaryDark).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortfolioCard extends StatelessWidget {
  const _PortfolioCard({required this.value, required this.pnl, required this.pnlPct});

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
          Text('Paper portfolio', style: context.typeLabel(12, p.heroCardMuted)),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.formatCompact(value), style: context.typeHeading.copyWith(color: p.heroCardFg)),
          const SizedBox(height: 4),
          Text(
            '${positive ? '+' : ''}${CurrencyFormatter.formatCompact(pnl)} (${IndexFormatter.formatPercent(pnlPct)})',
            style: context.typeLabel(13, positive ? p.positive : p.negative),
          ),
        ],
      ),
    );
  }
}
