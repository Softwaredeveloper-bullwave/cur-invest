import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/premium_ui_kit.dart';
import '../../../../core/widgets/shell_highlight_actions.dart';
import '../../../stocks/presentation/widgets/explore_feature_tile.dart';
import '../../../stocks/presentation/widgets/markets_quick_actions.dart';

enum AltMarketKind { crypto, forex }

/// Indian-style News / Bank / All shortcuts for crypto and forex.
class AltMarketShortcuts extends StatelessWidget {
  const AltMarketShortcuts({super.key, required this.kind});

  final AltMarketKind kind;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick access',
          style: context.typeLabel(12, context.palette.textMuted).copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
        ),
        const SizedBox(height: 10),
        ShellHighlightActionsRow(
          actions: [
            ShellHighlightAction(
              icon: Icons.newspaper_rounded,
              label: 'News',
              color: AppColors.blue,
              onTap: () => context.push(_newsRoute(kind)),
            ),
            ShellHighlightAction(
              icon: Icons.account_balance_rounded,
              label: 'Bank',
              color: AppColors.green,
              onTap: () => context.push(AppRoutes.bankDetails),
            ),
            ShellHighlightAction(
              icon: Icons.bookmark_rounded,
              label: 'Watchlist',
              color: const Color(0xFF9333EA),
              onTap: () => context.push(_watchlistRoute(kind)),
            ),
            ShellHighlightAction(
              icon: Icons.tune_rounded,
              label: 'Screener',
              color: AppColors.brandCyan,
              onTap: () => context.push(_screenerRoute(kind)),
            ),
            ShellHighlightAction(
              icon: Icons.account_balance_wallet_rounded,
              label: 'Wallet',
              color: AppColors.brandOrange,
              onTap: () => context.go(AppRoutes.wallet),
            ),
            ShellHighlightAction(
              icon: Icons.apps_rounded,
              label: 'All',
              color: AppColors.brandPrimary,
              onTap: () => showAltMarketAllSheet(context, kind),
            ),
          ],
        ),
      ],
    );
  }
}

void showAltMarketAllSheet(BuildContext context, AltMarketKind kind) {
  showMarketsMoreSheet(
    context,
    overflowItems: [
      ExploreFeatureItem(
        icon: Icons.newspaper_rounded,
        label: 'News',
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        onTap: () {
          Navigator.pop(context);
          context.push(_newsRoute(kind));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.account_balance_rounded,
        label: 'Bank',
        gradient: const [Color(0xFF059669), Color(0xFF6EE7B7)],
        onTap: () {
          Navigator.pop(context);
          context.push(AppRoutes.bankDetails);
        },
      ),
      ExploreFeatureItem(
        icon: Icons.bookmark_rounded,
        label: 'Watchlist',
        gradient: const [Color(0xFF9333EA), Color(0xFFEC4899)],
        onTap: () {
          Navigator.pop(context);
          context.push(_watchlistRoute(kind));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.tune_rounded,
        label: 'Screener',
        gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
        onTap: () {
          Navigator.pop(context);
          context.push(_screenerRoute(kind));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.trending_up_rounded,
        label: 'Movers',
        gradient: const [Color(0xFFEF4444), Color(0xFFF97316)],
        onTap: () {
          Navigator.pop(context);
          context.push(_moversRoute(kind));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.search_rounded,
        label: 'Search',
        gradient: const [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
        onTap: () {
          Navigator.pop(context);
          context.push(_searchRoute(kind));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.pie_chart_rounded,
        label: 'Portfolio',
        gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
        onTap: () {
          Navigator.pop(context);
          context.go(AppRoutes.portfolio);
        },
      ),
      ExploreFeatureItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Wallet',
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        onTap: () {
          Navigator.pop(context);
          context.go(AppRoutes.wallet);
        },
      ),
      ExploreFeatureItem(
        icon: Icons.school_rounded,
        label: 'Academy',
        gradient: const [Color(0xFF3B82F6), Color(0xFF22D3EE)],
        onTap: () {
          Navigator.pop(context);
          context.push(AppRoutes.documentCategoryPath('beginner'));
        },
      ),
      ExploreFeatureItem(
        icon: Icons.calculate_rounded,
        label: 'Calculator',
        gradient: const [Color(0xFF7C3AED), Color(0xFFA855F7)],
        onTap: () {
          Navigator.pop(context);
          context.push(AppRoutes.investmentCalculator);
        },
      ),
    ],
  );
}

class AltMarketEmptyHoldings extends StatelessWidget {
  const AltMarketEmptyHoldings({
    super.key,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.onCta,
  });

  final String title;
  final String subtitle;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.3),
                  AppColors.brandPrimary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppColors.brandPrimaryLight.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.pie_chart_outline_rounded,
              size: 36,
              color: AppColors.brandPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(title, style: context.typeSection(17)),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: context.typeSecondary(14),
          ),
          const SizedBox(height: 20),
          GradientActionButton(label: ctaLabel, onTap: onCta),
        ],
      ),
    );
  }
}

class AltMarketBottomSpacer extends StatelessWidget {
  const AltMarketBottomSpacer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: ShellLayout.contentBottomInset);
  }
}

String _newsRoute(AltMarketKind kind) =>
    kind == AltMarketKind.crypto ? AppRoutes.cryptoNews : AppRoutes.forexNews;

String _watchlistRoute(AltMarketKind kind) => kind == AltMarketKind.crypto
    ? AppRoutes.cryptoWatchlist
    : AppRoutes.forexWatchlist;

String _screenerRoute(AltMarketKind kind) => kind == AltMarketKind.crypto
    ? AppRoutes.cryptoScreener
    : AppRoutes.forexScreener;

String _moversRoute(AltMarketKind kind) =>
    kind == AltMarketKind.crypto ? AppRoutes.cryptoMovers : AppRoutes.forexMovers;

String _searchRoute(AltMarketKind kind) =>
    kind == AltMarketKind.crypto ? AppRoutes.cryptoSearch : AppRoutes.forexSearch;
