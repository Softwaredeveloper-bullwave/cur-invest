import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/custom_app_bar.dart';
import '../provider/forex_market_provider.dart';
import '../widgets/forex_pair_tile.dart';

class ForexMoversScreen extends StatefulWidget {
  const ForexMoversScreen({super.key});

  @override
  State<ForexMoversScreen> createState() => _ForexMoversScreenState();
}

class _ForexMoversScreenState extends State<ForexMoversScreen> {
  String _type = 'gainers';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForexMarketProvider>().loadMovers(_type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Forex Movers'),
      body: Consumer<ForexMarketProvider>(
        builder: (context, provider, _) {
          final rows = provider.movers(_type);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Gainers'),
                      selected: _type == 'gainers',
                      onSelected: (_) {
                        setState(() => _type = 'gainers');
                        provider.loadMovers('gainers');
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Losers'),
                      selected: _type == 'losers',
                      onSelected: (_) {
                        setState(() => _type = 'losers');
                        provider.loadMovers('losers');
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
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
