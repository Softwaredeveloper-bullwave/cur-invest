import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_coin_tile.dart';

class CryptoMoversScreen extends StatefulWidget {
  const CryptoMoversScreen({super.key});

  @override
  State<CryptoMoversScreen> createState() => _CryptoMoversScreenState();
}

class _CryptoMoversScreenState extends State<CryptoMoversScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabTypes = ['gainers', 'losers', 'trending', 'volume'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabTypes.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTab(0));
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadTab(_tabs.index);
    });
  }

  Future<void> _loadTab(int index) async {
    await context.read<CryptoMarketProvider>().loadMovers(_tabTypes[index]);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Crypto Movers',
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Gainers'),
            Tab(text: 'Losers'),
            Tab(text: 'Trending'),
            Tab(text: 'Volume'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: _tabTypes.map((type) {
          return Consumer<CryptoMarketProvider>(
            builder: (context, provider, _) {
              final items = provider.movers(type);
              if (items.isEmpty && provider.error == null) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingList(itemCount: 5),
                );
              }
              return RefreshIndicator(
                color: AppColors.brandCyan,
                onRefresh: () => provider.loadMovers(type),
                child: items.isEmpty
                    ? ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              provider.error ??
                                  'Market data is temporarily unavailable. Please try again.',
                              textAlign: TextAlign.center,
                              style: context.typeSecondary(14),
                            ),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (_, i) => CryptoCoinTile(asset: items[i]),
                      ),
              );
            },
          );
        }).toList(),
      ),
    );
  }
}
