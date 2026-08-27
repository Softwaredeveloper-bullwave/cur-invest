import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../provider/forex_market_provider.dart';
import '../widgets/forex_pair_tile.dart';

class ForexScreenerScreen extends StatefulWidget {
  const ForexScreenerScreen({super.key});

  @override
  State<ForexScreenerScreen> createState() => _ForexScreenerScreenState();
}

class _ForexScreenerScreenState extends State<ForexScreenerScreen> {
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForexMarketProvider>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Forex Screener'),
      body: Consumer<ForexMarketProvider>(
        builder: (context, provider, _) {
          final rows = _category == 'All'
              ? provider.pairs
              : provider.pairs.where((p) => p.category == _category).toList();
          return Column(
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: ['All', 'Majors', 'Crosses', 'Exotics'].map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: provider.isLoading && provider.pairs.isEmpty
                    ? const Padding(padding: EdgeInsets.all(16), child: LoadingList(itemCount: 6))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => ForexPairTile(pair: rows[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

