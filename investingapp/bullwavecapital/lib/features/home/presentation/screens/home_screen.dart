import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/paper_only_mode.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/fno_index_catalog.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/navigation/registration_completion.dart';
import '../../../../core/navigation/shell_navigation.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../models/investment_model.dart';
import '../../../goals/presentation/provider/goal_plan_provider.dart';
import '../../../goals/presentation/widgets/home_goals_section.dart';
import '../../../investment/data/featured_plans_catalog.dart';
import '../../../fno/presentation/provider/fno_flow_provider.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../notifications/presentation/provider/notification_provider.dart';
import '../../../../core/widgets/paper_trading_disclaimer.dart';
import '../../../wallet/presentation/provider/wallet_provider.dart';
import '../../../stocks/presentation/provider/stock_features_provider.dart';
import '../../../stocks/presentation/provider/stock_market_provider.dart';
import '../../../crypto/presentation/provider/crypto_market_provider.dart';
import '../../../crypto/presentation/screens/crypto_home_screen.dart';
import '../../../crypto/presentation/widgets/market_switcher.dart';
import '../provider/home_provider.dart';
import '../widgets/home_theme_a.dart';
import '../widgets/home_balance_cards.dart';
import '../widgets/home_clean_header.dart';
import '../widgets/home_ipo_section.dart';
import '../widgets/home_hero_background.dart';
import '../widgets/home_pending_actions.dart';
import '../widgets/home_quick_actions.dart';
import '../widgets/home_recent_activity.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/home_trending_strip.dart';
import '../widgets/market_overview.dart';
import '../widgets/news_banner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dueDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(RegistrationCompletion.maybeFinishRegistration(context));
      _checkGoalReminders();
      _loadEngagement();
    });
  }

  Future<void> _loadEngagement() async {
    if (!mounted) return;
    final features = context.read<StockFeaturesProvider>();
    await Future.wait([
      features.refreshIpoCalendar(limit: 6),
      features.prefetchHomeIndexExpiries(),
      context.read<StockMarketProvider>().ensureLoaded(),
      context.read<CryptoMarketProvider>().ensurePreferenceLoaded(),
      context.read<KycFlowProvider>().loadStatus(),
      if (!PaperOnlyMode.enabled)
        context.read<FnoFlowProvider>().ensureLoaded(),
      context.read<AuthProvider>().refreshProfile(),
    ]);
  }

  Future<void> _checkGoalReminders() async {
    if (PaperOnlyMode.enabled || _dueDialogShown || !mounted) return;
    final goals = context.read<GoalPlanProvider>();
    await goals.refreshReminders();
    if (!mounted || goals.dueGoals.isEmpty) return;
    _dueDialogShown = true;
    showGoalDueDialog(context, goals.dueGoals.first);
  }

  void _showQuickMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _MenuTile(
                icon: Icons.person_outline_rounded,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.profile);
                },
              ),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.settings);
                },
              ),
              _MenuTile(
                icon: Icons.support_agent_outlined,
                label: 'Support',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(AppRoutes.support);
                },
              ),
              if (!PaperOnlyMode.enabled)
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Transactions',
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push(AppRoutes.transactions);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CryptoMarketProvider>(
      builder: (context, cryptoMarket, _) {
        if (cryptoMarket.isCryptoActive) {
          return const CryptoHomeScreen(embedded: true);
        }
        return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: LoadingList(itemCount: 6, itemHeight: 80),
              ),
            ),
          );
        }

        final portfolio = provider.portfolio;
        final notificationCount = context
            .watch<NotificationProvider>()
            .unreadCount;
        final userName = context.watch<AuthProvider>().user?.displayName;
        final plans = PaperOnlyMode.enabled
            ? <InvestmentPlanModel>[]
            : _featuredPlansForHome(provider);
        final allQuickActions = _homeQuickActions(context);
        final practiceBalance = context.watch<WalletProvider>().practiceBalance;
        return SafeArea(
          child: RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: () async {
              await provider.refresh();
              await _loadEngagement();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HomeHeroBackground(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeCleanHeader(
                            notificationCount: notificationCount,
                            userName: userName,
                            onMenuTap: () => _showQuickMenu(context),
                            onNotificationTap: () =>
                                context.push(AppRoutes.notifications),
                          ),
                          const SizedBox(height: 10),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: MarketSwitcher(),
                          ),
                          const SizedBox(height: 18),
                          if (PaperOnlyMode.enabled) ...[
                            const PaperTradingDisclaimer(),
                            const SizedBox(height: 14),
                          ],
                          if (!PaperOnlyMode.enabled)
                            const HomePendingActionsSection(),
                          if (!PaperOnlyMode.enabled)
                            const SizedBox(height: 20),
                          if (PaperOnlyMode.enabled) const SizedBox(height: 4),
                          HomeBalanceCards(
                            portfolioValue: portfolio.currentValue,
                            walletBalance: PaperOnlyMode.enabled
                                ? practiceBalance
                                : portfolio.walletBalance,
                            dayPnl: portfolio.dayPnl,
                            onPortfolioTap: () =>
                                context.go(AppRoutes.portfolio),
                            onWalletTap: () => context.go(AppRoutes.wallet),
                          ),
                          const SizedBox(height: 20),
                          HomeSearchBar(
                            onTap: () => context.go(AppRoutes.invest),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Quick access',
                            style: context
                                .typeLabel(12, context.palette.textMuted)
                                .copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                          ),
                          const SizedBox(height: 10),
                          HomeQuickActionsCarousel(actions: allQuickActions),
                          const SizedBox(height: 18),
                          NewsHeadlineTicker(
                            headlines: provider.marketNews,
                            onTap: () => context.push(AppRoutes.stockNews),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: PremiumAlertBanner(
                        message: provider.error!,
                        type: PremiumAlertType.warning,
                        actionLabel: 'Retry',
                        onAction: () => provider.refresh(),
                      ),
                    ),
                  Consumer2<HomeProvider, StockMarketProvider>(
                    builder: (context, home, market, _) {
                      final indices = home.marketIndices.isNotEmpty
                          ? home.marketIndices
                          : market.marketIndices;
                      if (indices.isEmpty &&
                          !home.isLoading &&
                          !market.isLoading) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: PremiumAlertBanner(
                            message:
                                'Live market indices are unavailable. Pull to refresh.',
                            type: PremiumAlertType.warning,
                            actionLabel: 'Retry',
                            onAction: () async {
                              await home.refresh();
                              await market.refresh();
                            },
                          ),
                        );
                      }
                      if (indices.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return MarketOverview(
                        indices: indices,
                        expiryFor: (index) {
                          final symbol = FnoIndexCatalog.symbolForMarketIndex(
                            index.shortName,
                          );
                          if (symbol == null) return null;
                          final features =
                              context.read<StockFeaturesProvider>();
                          final expiry = features.optionSelectedExpiry(symbol);
                          return expiry.isNotEmpty ? expiry : null;
                        },
                      );
                    },
                  ),
                  Consumer<StockMarketProvider>(
                    builder: (context, market, _) {
                      if (market.trendingStocks.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return HomeTrendingStrip(
                        stocks: market.trendingStocks,
                        onSeeAll: () => context.go(AppRoutes.invest),
                      );
                    },
                  ),
                  Container(
                    width: double.infinity,
                    color: context.palette.bg,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!PaperOnlyMode.enabled && plans.isNotEmpty) ...[
                          HomeSectionHeader(
                            title: 'Featured Plans',
                            actionLabel: 'See All',
                            onAction: () =>
                                context.push(AppRoutes.featuredPlansList),
                            reserveFabSpace: true,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 148,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: plans.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final plan = plans[index];
                                return _FeaturedPlanChip(
                                  plan: plan,
                                  risk: _riskFor(plan.id),
                                  onTap: () => _openFeaturedPlan(context, plan),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        const HomeIpoSection(),
                        if (!PaperOnlyMode.enabled) ...[
                          const SizedBox(height: 24),
                          provider.goalPlans.isNotEmpty
                              ? HomeGoalsSection(
                                  goals: provider.goalPlans,
                                  onViewAll: () =>
                                      context.push(AppRoutes.goalPlans),
                                )
                              : _GoalPlansPromo(
                                  onTap: () =>
                                      context.push(AppRoutes.goalPlans),
                                ),
                        ],
                        if (!PaperOnlyMode.enabled) ...[
                          const SizedBox(height: 24),
                          HomeRecentActivity(
                            transactions: provider.recentTransactions,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(height: ShellLayout.contentBottomInset),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
      },
    );
  }

  String _riskFor(String id) {
    switch (id) {
      case 'PLAN003':
        return 'High';
      case 'PLAN002':
        return 'Medium';
      default:
        return 'Low';
    }
  }

  List<InvestmentPlanModel> _featuredPlansForHome(HomeProvider provider) {
    if (provider.featuredPlans.isNotEmpty) {
      return provider.featuredPlans.take(4).toList();
    }
    return FeaturedPlansCatalog.plans;
  }

  void _openFeaturedPlan(BuildContext context, InvestmentPlanModel plan) {
    context.push('${AppRoutes.featuredPlan}/${plan.id}', extra: plan);
  }

  List<HomeQuickAction> _homeQuickActions(BuildContext context) {
    final actions = <HomeQuickAction>[
      HomeQuickAction(
        icon: PhosphorIcons.chartLineUp,
        label: 'Markets',
        color: HomeThemeA.primary,
        onTap: () => context.go(AppRoutes.invest),
      ),
      if (!PaperOnlyMode.enabled)
        HomeQuickAction(
          icon: PhosphorIcons.wallet,
          label: 'Wallet',
          color: AppColors.brandCyan,
          onTap: () => context.go(AppRoutes.wallet),
        )
      else
        HomeQuickAction(
          icon: PhosphorIcons.wallet,
          label: 'Practice',
          color: AppColors.brandCyan,
          onTap: () => context.go(AppRoutes.wallet),
        ),
      if (!PaperOnlyMode.enabled) ...[
        HomeQuickAction(
          icon: PhosphorIcons.flag,
          label: 'Goals',
          color: AppColors.brandPink,
          onTap: () => context.push(AppRoutes.goalPlans),
        ),
        HomeQuickAction(
          icon: PhosphorIcons.piggyBank,
          label: 'Plans',
          color: AppColors.brandOrange,
          onTap: () => context.push(AppRoutes.featuredPlansList),
        ),
      ],
      HomeQuickAction(
        icon: PhosphorIcons.bookmarkSimple,
        label: 'Watchlist',
        color: AppColors.blue,
        onTap: () => context.push(AppRoutes.watchlist),
      ),
      HomeQuickAction(
        icon: PhosphorIcons.calendarBlank,
        label: 'IPO',
        color: AppColors.brandCyan,
        onTap: () => context.push(AppRoutes.ipoCalendar),
      ),
      HomeQuickAction(
        icon: PhosphorIcons.flask,
        label: 'Paper',
        color: AppColors.brandOrange,
        onTap: () => pushOverShell(context, AppRoutes.paperTrading),
      ),
      HomeQuickAction(
        icon: PhosphorIcons.bell,
        label: 'Alerts',
        color: AppColors.brandPink,
        onTap: () => context.push(AppRoutes.priceAlerts),
      ),
      if (!PaperOnlyMode.enabled)
        HomeQuickAction(
          icon: PhosphorIcons.repeat,
          label: 'SIP',
          color: HomeThemeA.primary,
          onTap: () => context.push(AppRoutes.sipTracker),
        ),
      HomeQuickAction(
        icon: PhosphorIcons.newspaper,
        label: 'News',
        color: AppColors.blue,
        onTap: () => context.push(AppRoutes.stockNews),
      ),
    ];
    return actions;
  }
}

class _FeaturedPlanChip extends StatelessWidget {
  final InvestmentPlanModel plan;
  final String risk;
  final VoidCallback onTap;

  const _FeaturedPlanChip({
    required this.plan,
    required this.risk,
    required this.onTap,
  });

  IconData _iconForPlan() {
    switch (plan.id) {
      case 'PLAN003':
        return PhosphorIcons.crown;
      case 'PLAN002':
        return PhosphorIcons.medal;
      default:
        return PhosphorIcons.diamondsFour;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final riskColor = _riskColor(p);

    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: 124,
        padding: const EdgeInsets.all(16),
        decoration: HomeThemeA.cardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: p.iconCircleDecoration(),
              child: Icon(_iconForPlan(), color: p.primaryDark, size: 18),
            ),
            const Spacer(),
            Text(
              plan.name.split(' ').last,
              style: context.typeCardTitle(14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${plan.annualReturnRate.toStringAsFixed(0)}% p.a.',
              style: context.typeLabel(12, p.positive),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: riskColor.withValues(alpha: 0.22)),
              ),
              child: Text(
                risk,
                style: context
                    .typeLabel(11, riskColor)
                    .copyWith(letterSpacing: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(ThemePalette p) {
    switch (risk.toLowerCase()) {
      case 'high':
        return p.negative;
      case 'medium':
        return p.accentOrange;
      default:
        return p.positive;
    }
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _GoalPlansPromo extends StatelessWidget {
  final VoidCallback onTap;
  const _GoalPlansPromo({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HomeThemeA.cardRadius),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomeThemeA.cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.primarySoft, p.card],
            ),
            border: Border.all(color: p.primaryBorder),
            boxShadow: p.isDark
                ? []
                : [
                    BoxShadow(
                      color: p.primary.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: p.iconCircleDecoration(
                  backgroundColor: p.primary.withValues(alpha: 0.35),
                  borderColor: p.primaryBorder,
                ),
                child: Icon(PhosphorIcons.flag, color: p.primaryDark, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start a Goal Plan', style: context.typeSection(16)),
                    const SizedBox(height: 4),
                    Text(
                      'Earn 8%–16% p.a. on your life goals',
                      style: context.typeSecondary(14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Explore Goals', style: context.typeAction(13)),
                        const SizedBox(width: 4),
                        Icon(
                          PhosphorIcons.arrowRight,
                          size: 14,
                          color: p.primaryDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
