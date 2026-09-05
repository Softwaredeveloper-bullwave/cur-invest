import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/live_tick_price.dart';
import '../../../../models/forex_models.dart';
import '../provider/forex_market_provider.dart';
import 'package:provider/provider.dart';

class ForexPairTile extends StatelessWidget {
  const ForexPairTile({super.key, required this.pair, this.onTap});

  final ForexPairModel pair;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = pair.isPositive ? p.positive : p.negative;
    final tape = context.watch<ForexMarketProvider>().tickTape.of(pair.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => context.push(AppRoutes.forexDetailPath(pair.id)),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: p.cardDecoration(radius: 22),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.primaryBorder),
                  ),
                  child: Text(
                    pair.baseCurrency.isNotEmpty
                        ? pair.baseCurrency.substring(0, pair.baseCurrency.length.clamp(0, 2))
                        : pair.symbol.substring(0, pair.symbol.length.clamp(0, 2)),
                    style: context.typeLabel(12, p.primaryDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pair.symbol, style: context.typeCardTitle(15)),
                      const SizedBox(height: 3),
                      Text(
                        pair.name,
                        style: context.typeSecondary(13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (tape.length >= 2) ...[
                  LiveSparkline(
                    values: tape,
                    positive: pair.isPositive,
                    width: 56,
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LiveTickPrice(
                      value: pair.currentPrice,
                      text: _formatPx(pair.currentPrice),
                      style: context.typeCardTitle(14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      IndexFormatter.formatPercent(pair.change24hPct),
                      style: context.typeLabel(12, changeColor).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatPx(double value) {
    if (value >= 100) return value.toStringAsFixed(2);
    if (value >= 10) return value.toStringAsFixed(3);
    return value.toStringAsFixed(5);
  }
}
