import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/forex_market_provider.dart';
import '../widgets/forex_pair_tile.dart';

class ForexSearchScreen extends StatefulWidget {
  const ForexSearchScreen({super.key});

  @override
  State<ForexSearchScreen> createState() => _ForexSearchScreenState();
}

class _ForexSearchScreenState extends State<ForexSearchScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForexMarketProvider>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Search Forex'),
      body: Consumer<ForexMarketProvider>(
        builder: (context, provider, _) {
          final results = _controller.text.trim().isEmpty ? provider.pairs : provider.searchResults;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'EURUSD, GBP, rupee…',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: provider.search,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) => ForexPairTile(pair: results[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
