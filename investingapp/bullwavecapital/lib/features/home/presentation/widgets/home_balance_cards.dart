import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';

enum _BalanceCardStyle { hero, accent }

class HomeBalanceCards extends StatelessWidget {
  final double portfolioValue;
  final double walletBalance;
  final double dayPnl;
  final VoidCallback? onPortfolioTap;
  final VoidCallback? onWalletTap;

  const HomeBalanceCards({
    super.key,
    required this.portfolioValue,
    required this.walletBalance,
    this.dayPnl = 0,
    this.onPortfolioTap,
    this.onWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pnlPositive = dayPnl >= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _BalanceCard(
            style: _BalanceCardStyle.hero,
            icon: PhosphorIcons.chartPie,
            amount: portfolioValue,
            label: 'Portfolio',
            sublabel: dayPnl != 0
                ? '${pnlPositive ? '+' : ''}${CurrencyFormatter.formatCompact(dayPnl)} today'
                : 'Total holdings value',
            pnlBadge: dayPnl != 0
                ? _PnlBadge(value: dayPnl, positive: pnlPositive)
                : null,
            onTap: onPortfolioTap,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BalanceCard(
            style: _BalanceCardStyle.accent,
            icon: PhosphorIcons.wallet,
            amount: walletBalance,
            label: 'Wallet',
            sublabel: walletBalance > 0 ? 'Ready to invest' : 'Tap to add funds',
            trailing: walletBalance <= 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: p.accentSurfaceFg.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+ Add',
                      style: ThemeAType.label(size: 10, color: p.accentSurfaceFg)
                          .copyWith(fontWeight: FontWeight.w800),
                    ),
                  )
                : null,
            onTap: onWalletTap,
          ),
        ),
      ],
    );
  }
}

class _PnlBadge extends StatelessWidget {
  final double value;
  final bool positive;

  const _PnlBadge({required this.value, required this.positive});

  @override
  Widget build(BuildContext context) {
    final color = positive ? const Color(0xFF4ADE80) : const Color(0xFFFF6B6B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? PhosphorIcons.trendUp : PhosphorIcons.trendDown,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            CurrencyFormatter.formatCompact(value.abs()),
            style: ThemeAType.label(size: 10, color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final _BalanceCardStyle style;
  final IconData icon;
  final double amount;
  final String label;
  final String sublabel;
  final Widget? pnlBadge;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _BalanceCard({
    required this.style,
    required this.icon,
    required this.amount,
    required this.label,
    required this.sublabel,
    this.pnlBadge,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isHero = style == _BalanceCardStyle.hero;

    final fg = isHero ? p.heroCardFg : p.accentSurfaceFg;
    final muted = isHero ? p.heroCardMuted : p.accentSurfaceFg.withValues(alpha: 0.7);
    final decoration = isHero ? p.heroCardDecoration() : p.accentCardDecoration();
    final iconBg = isHero
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.1);
    final iconFg = isHero ? p.heroCardFg : p.accentSurfaceFg;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 148,
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 18, color: iconFg),
                    ),
                    const Spacer(),
                    if (pnlBadge != null) pnlBadge!,
                    if (trailing != null) trailing!,
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatCompact(amount),
                    style: ThemeAType.price(size: 26, color: fg),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: ThemeAType.cardTitle(size: 13, color: fg),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: ThemeAType.secondary(size: 11, color: muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
