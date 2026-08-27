import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/forex_market_provider.dart';

class ForexPortfolioScreen extends StatelessWidget {
  const ForexPortfolioScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final body = Consumer<ForexMarketProvider>(
      builder: (context, provider, _) {
        final portfolio = provider.portfolio;
        if (portfolio == null) {
          return const Center(child: Text('No paper forex positions yet.'));
        }
        final p = context.palette;
        return RefreshIndicator(
          onRefresh: provider.loadPortfolio,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text('Paper wallet', style: context.typeSecondary(13)),
              Text(
                CurrencyFormatter.formatCompact(portfolio.walletBalance),
                style: context.typeHeading,
              ),
              const SizedBox(height: 8),
              Text(
                'P&L ${IndexFormatter.formatPercent(portfolio.profitLossPercent)}',
                style: context.typeLabel(14, portfolio.isPositive ? p.positive : p.negative),
              ),
              const SizedBox(height: 16),
              ...portfolio.holdings.map(
                (h) => ListTile(
                  title: Text(h.symbol),
                  subtitle: Text('Qty ${h.quantity}'),
                  trailing: Text(CurrencyFormatter.formatCompact(h.currentValue)),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (embedded) return SafeArea(child: body);
    return Scaffold(
      appBar: const CustomAppBar(title: 'Forex Portfolio'),
      body: body,
    );
  }
}
