import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_a.dart';
import '../provider/crypto_market_provider.dart';

class MarketSwitcher extends StatelessWidget {
  const MarketSwitcher({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<CryptoMarketProvider>();

    // Always offer both markets — switching is exclusive (one at a time).
    final current =
        provider.activeMarket == 'crypto' ? 'crypto' : 'indian';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: p.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          icon: Icon(
            Icons.expand_more_rounded,
            size: compact ? 18 : 20,
            color: p.textGrey,
          ),
          style: context
              .typeLabel(compact ? 12 : 13, p.textDark)
              .copyWith(fontWeight: FontWeight.w700),
          borderRadius: BorderRadius.circular(12),
          items: const [
            DropdownMenuItem(
              value: 'indian',
              child: Text('🇮🇳 Indian Market'),
            ),
            DropdownMenuItem(
              value: 'crypto',
              child: Text('₿ Crypto Market'),
            ),
          ],
          onChanged: (value) {
            if (value != null) provider.switchMarket(value);
          },
        ),
      ),
    );
  }
}
