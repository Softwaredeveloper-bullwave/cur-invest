import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_coin_tile.dart';

class CryptoScreenerScreen extends StatefulWidget {
  const CryptoScreenerScreen({super.key});

  @override
  State<CryptoScreenerScreen> createState() => _CryptoScreenerScreenState();
}

class _CryptoScreenerScreenState extends State<CryptoScreenerScreen> {
  String _sort = 'market_cap_desc';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<CryptoMarketProvider>().loadScreener(sort: _sort);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Crypto Screener'),
      body: Consumer<CryptoMarketProvider>(
        builder: (context, provider, _) {
          final results = provider.screener?.results ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: DropdownButtonFormField<String>(
                  value: _sort,
                  decoration: const InputDecoration(labelText: 'Sort by'),
                  items: const [
                    DropdownMenuItem(value: 'market_cap_desc', child: Text('Market cap')),
                    DropdownMenuItem(value: 'volume_desc', child: Text('Volume')),
                    DropdownMenuItem(value: 'price_change_percentage_24h_desc', child: Text('Top gainers')),
                    DropdownMenuItem(value: 'price_change_percentage_24h_asc', child: Text('Top losers')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _sort = v);
                    _load();
                  },
                ),
              ),
              Expanded(
                child: provider.isLoading && results.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: LoadingList(itemCount: 5),
                      )
                    : RefreshIndicator(
                        color: AppColors.brandCyan,
                        onRefresh: _load,
                        child: results.isEmpty
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
                                itemCount: results.length,
                                itemBuilder: (_, i) => CryptoCoinTile(asset: results[i]),
                              ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
