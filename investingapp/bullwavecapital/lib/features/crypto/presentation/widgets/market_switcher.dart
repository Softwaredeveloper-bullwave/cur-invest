import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../forex/presentation/provider/forex_market_provider.dart';
import '../provider/crypto_market_provider.dart';

class MarketSwitcher extends StatelessWidget {
  const MarketSwitcher({super.key, this.compact = false});

  final bool compact;

  static const _markets = <(String, String)>[
    ('indian', '🇮🇳 Indian Market'),
    ('crypto', '₿ Crypto Market'),
    ('forex', '💱 Forex Market'),
  ];

  String _labelFor(String id) {
    for (final row in _markets) {
      if (row.$1 == id) return row.$2;
    }
    return '🇮🇳 Indian Market';
  }

  Future<void> _openPicker(BuildContext context, CryptoMarketProvider provider) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final p = ctx.palette;
        final bottomGap = MediaQuery.of(ctx).padding.bottom + 88;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomGap),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Choose market', style: ctx.typeCardTitle(16)),
                  ),
                ),
                ListTile(
                  title: const Text('🇮🇳 Indian Market'),
                  trailing: provider.activeMarket == 'indian'
                      ? Icon(Icons.check_rounded, color: p.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, 'indian'),
                ),
                ListTile(
                  title: const Text('₿ Crypto Market'),
                  trailing: provider.activeMarket == 'crypto'
                      ? Icon(Icons.check_rounded, color: p.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, 'crypto'),
                ),
                ListTile(
                  title: const Text('💱 Forex Market'),
                  trailing: provider.activeMarket == 'forex'
                      ? Icon(Icons.check_rounded, color: p.primary)
                      : null,
                  onTap: () => Navigator.pop(ctx, 'forex'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) return;
    await provider.switchMarket(selected);
    if (!context.mounted) return;
    if (selected == 'forex') {
      await context.read<ForexMarketProvider>().ensureLoaded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<CryptoMarketProvider>();
    final current = provider.isForexActive
        ? 'forex'
        : provider.isCryptoActive
            ? 'crypto'
            : 'indian';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context, provider),
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(compact ? 12 : 14),
            border: Border.all(color: p.borderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _labelFor(current),
                style: context
                    .typeLabel(compact ? 12 : 13, p.textDark)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.expand_more_rounded,
                size: compact ? 18 : 20,
                color: p.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
