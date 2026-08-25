import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_coin_tile.dart';

class CryptoWatchlistScreen extends StatefulWidget {
  const CryptoWatchlistScreen({super.key});

  @override
  State<CryptoWatchlistScreen> createState() => _CryptoWatchlistScreenState();
}

class _CryptoWatchlistScreenState extends State<CryptoWatchlistScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CryptoMarketProvider>().refreshAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Crypto Watchlist'),
      body: Consumer<CryptoMarketProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.watchlist.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 4),
            );
          }
          if (provider.watchlist.isEmpty) {
            return Center(
              child: Text(
                'Star coins from detail screens to track them here.',
                style: context.typeSecondary(14),
                textAlign: TextAlign.center,
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.brandCyan,
            onRefresh: provider.refreshAll,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.watchlist.length,
              itemBuilder: (_, i) {
                final item = provider.watchlist[i];
                return CryptoCoinTile(
                  asset: item.toAsset(),
                  trailing: IconButton(
                    icon: const Icon(Icons.star_rounded, color: AppColors.brandOrange),
                    onPressed: () => provider.toggleWatchlist(item.assetId),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
