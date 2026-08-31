import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/app_screen_background.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/expiry_highlight.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../stocks/presentation/utils/option_trading_flow.dart';
import '../../../stocks/presentation/widgets/option_chain_table.dart';
import '../provider/alt_option_chain_provider.dart';
import '../widgets/alt_market_shortcuts.dart';

class AltOptionChainScreen extends StatefulWidget {
  const AltOptionChainScreen({
    super.key,
    required this.kind,
    required this.underlyingId,
  });

  final AltMarketKind kind;
  final String underlyingId;

  @override
  State<AltOptionChainScreen> createState() => _AltOptionChainScreenState();
}

class _AltOptionChainScreenState extends State<AltOptionChainScreen> {
  late String _underlyingId;

  static const _cryptoList = [
    ('bitcoin', 'BTC', AppColors.brandOrange),
    ('ethereum', 'ETH', AppColors.blue),
    ('solana', 'SOL', AppColors.brandPurple),
    ('ripple', 'XRP', AppColors.brandCyan),
    ('binancecoin', 'BNB', AppColors.commodityGold),
  ];

  static const _forexList = [
    ('eurusd', 'EUR/USD', AppColors.blue),
    ('gbpusd', 'GBP/USD', AppColors.brandPurple),
    ('usdjpy', 'USD/JPY', AppColors.red),
    ('usdinr', 'USD/INR', AppColors.brandOrange),
    ('audusd', 'AUD/USD', AppColors.green),
  ];

  List<(String, String, Color)> get _catalog =>
      widget.kind == AltMarketKind.crypto ? _cryptoList : _forexList;

  bool get _isCrypto => widget.kind == AltMarketKind.crypto;

  @override
  void initState() {
    super.initState();
    _underlyingId = _normalize(widget.underlyingId);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String _normalize(String raw) {
    final id = raw.trim().toLowerCase().replaceAll('/', '').replaceAll('-', '');
    const aliases = {
      'btc': 'bitcoin',
      'eth': 'ethereum',
      'sol': 'solana',
      'xrp': 'ripple',
      'bnb': 'binancecoin',
    };
    if (_isCrypto) return aliases[id] ?? (id.isEmpty ? 'bitcoin' : id);
    return id.isEmpty ? 'eurusd' : id;
  }

  Future<void> _load({String? expiry}) {
    return context.read<AltOptionChainProvider>().load(
      widget.kind,
      _underlyingId,
      expiry: expiry,
    );
  }

  (int strikeDecimals, int ltpDecimals, double atmHalfWidth) _display(double spot) {
    if (spot >= 1000) return (0, 2, 250);
    if (spot >= 100) return (1, 2, 2.5);
    if (spot >= 10) return (2, 3, 0.5);
    if (spot >= 1) return (4, 4, 0.0025);
    return (4, 5, 0.0025);
  }

  String _formatSpot(double spot) {
    if (spot >= 1000) return spot.toStringAsFixed(2);
    if (spot >= 10) return spot.toStringAsFixed(3);
    return spot.toStringAsFixed(5);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final title = _isCrypto ? 'Crypto F&O' : 'Forex F&O';

    return Scaffold(
      body: AppScreenBackground(
        child: Column(
          children: [
            PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: CustomAppBar(
                title: title,
                subtitle: 'Paper CE/PE · USD',
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _catalog.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, label, accent) = _catalog[i];
                  final selected = id == _underlyingId;
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    showCheckmark: false,
                    avatar: selected
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    selectedColor: accent.withValues(alpha: 0.18),
                    backgroundColor: colors.surfaceSecondary,
                    side: BorderSide(
                      color: selected ? accent.withValues(alpha: 0.5) : colors.border,
                    ),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? accent : colors.textSecondary,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      if (id == _underlyingId) return;
                      setState(() => _underlyingId = id);
                      _load();
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: Consumer<AltOptionChainProvider>(
                builder: (context, provider, _) {
                  final loading = provider.isLoading(widget.kind, _underlyingId);
                  final chain = provider.contracts(widget.kind, _underlyingId);
                  final error = provider.error(widget.kind, _underlyingId);
                  final spot = provider.spot(widget.kind, _underlyingId);
                  final symbol = provider.symbol(widget.kind, _underlyingId);

                  if (loading && chain.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: LoadingList(itemCount: 6, itemHeight: 56),
                    );
                  }

                  if (chain.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.candlestick_chart_outlined,
                              size: 48,
                              color: colors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              error ?? 'No options data',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final expiries = provider.expiries(widget.kind, _underlyingId);
                  final selectedExpiry = provider.selectedExpiry(
                    widget.kind,
                    _underlyingId,
                  );
                  final display = _display(spot);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: AppDecorations.card(
                            context,
                            premium: true,
                            glow: true,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      symbol.isEmpty ? 'Spot' : '$symbol spot',
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '\$${_formatSpot(spot)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                      ),
                                    ),
                                    Text(
                                      'Virtual funds · Friday expiries',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.green.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bolt_rounded,
                                      size: 14,
                                      color: AppColors.green,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'PAPER',
                                      style: TextStyle(
                                        color: AppColors.green,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (expiries.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 46,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: expiries.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final expiry = expiries[i];
                              final selected = expiry == selectedExpiry;
                              return ExpirySelectorChip(
                                expiryIso: expiry,
                                selected: selected,
                                onTap: loading
                                    ? null
                                    : () => _load(expiry: expiry),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Tap CE or PE price to buy or sell with practice funds',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: OptionChainTable(
                          contracts: chain,
                          spot: spot,
                          strikeDecimals: display.$1,
                          ltpDecimals: display.$2,
                          atmHalfWidth: display.$3,
                          currencySymbol: '\$',
                          onContractTap: (contract) =>
                              openOptionContractTradingPad(
                                context,
                                contract: contract,
                                chainContext: _isCrypto
                                    ? OptionChainContext.crypto
                                    : OptionChainContext.forex,
                              ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
