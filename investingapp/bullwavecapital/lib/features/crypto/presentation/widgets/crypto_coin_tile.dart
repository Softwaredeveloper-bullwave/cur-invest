import 'package:flutter/material.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/crypto_models.dart';
import 'crypto_mini_chart.dart';
import 'package:go_router/go_router.dart';

class CryptoCoinTile extends StatelessWidget {
  const CryptoCoinTile({
    super.key,
    required this.asset,
    this.onTap,
    this.showSparkline = true,
    this.trailing,
  });

  final CryptoAssetModel asset;
  final VoidCallback? onTap;
  final bool showSparkline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final changeColor = asset.isPositive ? p.positive : p.negative;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => context.push(AppRoutes.cryptoDetailPath(asset.id)),
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: p.cardDecoration(radius: 22),
            child: Row(
              children: [
                _CoinAvatar(imageUrl: asset.imageUrl, symbol: asset.symbol),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.symbol, style: context.typeCardTitle(15)),
                      const SizedBox(height: 3),
                      Text(
                        asset.name,
                        style: context.typeSecondary(13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (showSparkline && asset.sparkline.isNotEmpty) ...[
                  CryptoMiniChart(
                    values: asset.sparkline,
                    positive: asset.isPositive,
                    width: 56,
                    height: 28,
                  ),
                  const SizedBox(width: 12),
                ],
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatUsd(asset.currentPrice),
                      style: context.typeCardTitle(14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      IndexFormatter.formatPercent(asset.change24hPct),
                      style: context.typeLabel(12, changeColor)
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatUsd(double value) {
    if (value >= 1000) return '\$${value.toStringAsFixed(2)}';
    if (value >= 1) return '\$${value.toStringAsFixed(2)}';
    return '\$${value.toStringAsFixed(4)}';
  }
}

class _CoinAvatar extends StatelessWidget {
  const _CoinAvatar({required this.imageUrl, required this.symbol});

  final String imageUrl;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          imageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(context),
        ),
      );
    }
    return _fallback(context);
  }

  Widget _fallback(BuildContext context) {
    final p = context.palette;
    final initials = symbol.length >= 2 ? symbol.substring(0, 2) : symbol;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.primarySoft,
        shape: BoxShape.circle,
        border: Border.all(color: p.primaryBorder),
      ),
      child: Text(initials, style: context.typeLabel(13, p.primaryDark)),
    );
  }
}
