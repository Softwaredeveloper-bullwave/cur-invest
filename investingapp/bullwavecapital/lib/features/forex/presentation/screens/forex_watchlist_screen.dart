import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/forex_market_provider.dart';

class ForexWatchlistScreen extends StatelessWidget {
  const ForexWatchlistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Forex Watchlist'),
      body: Consumer<ForexMarketProvider>(
        builder: (context, provider, _) {
          if (provider.watchlist.isEmpty) {
            return const Center(child: Text('Star a pair on its detail page to watch it.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.watchlist.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final item = provider.watchlist[i];
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: context.palette.card,
                title: Text(item.symbol),
                subtitle: Text(item.name),
                trailing: IconButton(
                  icon: const Icon(Icons.star_rounded),
                  onPressed: () => provider.toggleWatchlist(item.pairId),
                ),
                onTap: () => context.push(AppRoutes.forexDetailPath(item.pairId)),
              );
            },
          );
        },
      ),
    );
  }
}
