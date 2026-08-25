import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_coin_tile.dart';

class CryptoSearchScreen extends StatefulWidget {
  const CryptoSearchScreen({super.key});

  @override
  State<CryptoSearchScreen> createState() => _CryptoSearchScreenState();
}

class _CryptoSearchScreenState extends State<CryptoSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      context.read<CryptoMarketProvider>().search(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Search Crypto'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Search by name or symbol',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          Expanded(
            child: Consumer<CryptoMarketProvider>(
              builder: (context, provider, _) {
                if (provider.searchQuery.isEmpty) {
                  return Center(
                    child: Text(
                      'Find Bitcoin, Ethereum, and 1000+ assets',
                      style: context.typeSecondary(14),
                    ),
                  );
                }
                if (provider.searchResults.isEmpty && provider.error == null) {
                  return const Center(child: LoadingList(itemCount: 4));
                }
                if (provider.searchResults.isEmpty) {
                  return Center(
                    child: Text(
                      provider.error ??
                          'Market data is temporarily unavailable. Please try again.',
                      style: context.typeSecondary(14),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: provider.searchResults.length,
                  itemBuilder: (_, i) => CryptoCoinTile(asset: provider.searchResults[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
