import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../../models/crypto_models.dart';
import '../../../../models/stock_model.dart';
import '../provider/crypto_market_provider.dart';
import '../widgets/crypto_detail_chart.dart';

class CryptoDetailScreen extends StatefulWidget {
  const CryptoDetailScreen({super.key, required this.assetId});

  final String assetId;

  @override
  State<CryptoDetailScreen> createState() => _CryptoDetailScreenState();
}

class _CryptoDetailScreenState extends State<CryptoDetailScreen> {
  CryptoAssetModel? _asset;
  List<CandleModel> _candles = const [];
  String _period = '1D';
  bool _loadingAsset = true;
  bool _loadingChart = true;
  String? _error;

  String get _resolvedId {
    final raw = widget.assetId.trim();
    if (raw.isEmpty) return raw;
    final lower = raw.toLowerCase();
    const aliases = {
      'btc': 'bitcoin',
      'eth': 'ethereum',
      'sol': 'solana',
      'xrp': 'ripple',
      'ada': 'cardano',
      'doge': 'dogecoin',
      'bnb': 'binancecoin',
      'usdt': 'tether',
      'usdc': 'usd-coin',
    };
    return aliases[lower] ?? lower;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loadingAsset = true;
      _loadingChart = true;
      _error = null;
    });
    final api = BullwaveApi.instance;
    final id = _resolvedId;
    final providerAssets = context.read<CryptoMarketProvider>().assets;
    CryptoAssetModel? cached;
    for (final a in providerAssets) {
      if (a.id.toLowerCase() == id ||
          a.symbol.toLowerCase() == id ||
          a.symbol.toLowerCase() == widget.assetId.trim().toLowerCase()) {
        cached = a;
        break;
      }
    }

    try {
      final asset = await api.getCryptoAsset(id);
      if (!mounted) return;
      setState(() {
        _asset = asset;
        _loadingAsset = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _asset = cached;
          _loadingAsset = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = e.message;
          _loadingAsset = false;
          _loadingChart = false;
        });
        return;
      }
    } catch (_) {
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _asset = cached;
          _loadingAsset = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Market data is temporarily unavailable. Please try again.';
          _loadingAsset = false;
          _loadingChart = false;
        });
        return;
      }
    }

    await _loadChart(_period);
  }

  Future<void> _loadChart(String period) async {
    setState(() {
      _loadingChart = true;
      _period = period;
    });
    try {
      final chart = await BullwaveApi.instance.getCryptoChart(
        _resolvedId,
        period: period,
      );
      if (!mounted) return;
      var candles = chart.candles;
      if (candles.length < 2) {
        candles = _candlesFromSparkline(_asset, fallbackPrice: _asset?.currentPrice);
      }
      setState(() {
        _candles = candles;
        _loadingChart = false;
      });
    } catch (_) {
      if (!mounted) return;
      final fallback = _candlesFromSparkline(
        _asset,
        fallbackPrice: _asset?.currentPrice,
      );
      setState(() {
        if (fallback.length >= 2) _candles = fallback;
        _loadingChart = false;
      });
    }
  }

  static List<CandleModel> _candlesFromSparkline(
    CryptoAssetModel? asset, {
    double? fallbackPrice,
  }) {
    final spark = asset?.sparkline ?? const <double>[];
    final price = fallbackPrice ?? asset?.currentPrice ?? 0;
    final values = spark.where((v) => v > 0).toList();
    if (values.length < 2 && price > 0) {
      values
        ..clear()
        ..add(price * 0.985)
        ..add(price);
    }
    if (values.length < 2) return const [];
    final now = DateTime.now();
    return [
      for (var i = 0; i < values.length; i++)
        CandleModel(
          time: now.subtract(Duration(minutes: (values.length - 1 - i) * 15)),
          open: i == 0 ? values[i] : values[i - 1],
          high: i == 0 ? values[i] : (values[i] > values[i - 1] ? values[i] : values[i - 1]),
          low: i == 0 ? values[i] : (values[i] < values[i - 1] ? values[i] : values[i - 1]),
          close: values[i],
          volume: 0,
        ),
    ];
  }

  Future<void> _paperTrade(String side) async {
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) =>
          _QuantityDialog(side: side, symbol: _asset?.symbol ?? ''),
    );
    if (qty == null || qty <= 0 || !mounted) return;
    final provider = context.read<CryptoMarketProvider>();
    final result = await provider.placePaperOrder(
      assetId: _asset?.id.isNotEmpty == true ? _asset!.id : _resolvedId,
      side: side,
      quantity: qty,
    );
    if (!mounted) return;
    if (result != null) {
      AppSnackbar.success(context, 'PAPER TRADING order placed');
    } else {
      AppSnackbar.error(
        context,
        provider.error ?? 'Order failed. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final provider = context.watch<CryptoMarketProvider>();
    final watchId = _asset?.id.isNotEmpty == true ? _asset!.id : _resolvedId;
    final inWatchlist = provider.isInWatchlist(watchId);

    return Scaffold(
      appBar: CustomAppBar(
        title: _asset?.symbol.isNotEmpty == true
            ? _asset!.symbol
            : widget.assetId.toUpperCase(),
        actions: [
          IconButton(
            icon: Icon(
              inWatchlist ? Icons.star_rounded : Icons.star_outline_rounded,
            ),
            onPressed: () => provider.toggleWatchlist(watchId),
          ),
        ],
      ),
      body: _loadingAsset
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingList(itemCount: 4),
            )
          : _asset == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error ?? 'Asset not found',
                          textAlign: TextAlign.center,
                          style: context.typeSecondary(14),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.brandCyan,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: p.primaryBorder),
                          ),
                          child: Text(
                            'PAPER TRADING — Simulated orders only',
                            style: context
                                .typeLabel(12, p.primaryDark)
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(_asset!.name, style: context.typeSecondary(14)),
                        const SizedBox(height: 4),
                        Text(
                          _formatUsd(_asset!.currentPrice),
                          style: context.typeHeading.copyWith(fontSize: 32),
                        ),
                        Text(
                          IndexFormatter.formatPercent(_asset!.change24hPct),
                          style: context.typeLabel(
                            14,
                            _asset!.isPositive ? p.positive : p.negative,
                          ),
                        ),
                        const SizedBox(height: 16),
                        CryptoDetailChart(
                          symbol: _asset!.symbol,
                          candles: _candles,
                          isLoading: _loadingChart,
                          selectedPeriod: _period,
                          onPeriodSelected: _loadChart,
                          lastPrice: _asset!.currentPrice,
                        ),
                        if (_hasOptions) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => context.push(
                                AppRoutes.cryptoOptionsPath(_resolvedId),
                              ),
                              icon: const Icon(Icons.candlestick_chart_rounded),
                              label: const Text('Option chain · Paper F&O'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ScrollReveal(child: _StatsGrid(asset: _asset!)),
                        const SizedBox(height: 20),
                        if (_asset!.description.isNotEmpty) ...[
                          ScrollReveal(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('About', style: context.typeSection(16)),
                                const SizedBox(height: 8),
                                Text(
                                  _asset!.description
                                      .replaceAll(RegExp(r'<[^>]*>'), ' '),
                                  style: context.typeBody(14),
                                  maxLines: 8,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: () => _paperTrade('BUY'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.positive,
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('BUY · PAPER TRADING'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _paperTrade('SELL'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: p.negative,
                                  side: BorderSide(color: p.negative),
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Text('SELL · PAPER TRADING'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  static String _formatUsd(double value) {
    if (value >= 1) return '\$${value.toStringAsFixed(2)}';
    return '\$${value.toStringAsFixed(4)}';
  }

  bool get _hasOptions {
    const listed = {
      'bitcoin',
      'ethereum',
      'solana',
      'ripple',
      'binancecoin',
    };
    return listed.contains(_resolvedId);
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.asset});

  final CryptoAssetModel asset;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('24h High', _formatUsd(asset.high24h)),
      ('24h Low', _formatUsd(asset.low24h)),
      ('Volume', _compact(asset.volume)),
      ('Market Cap', _compact(asset.marketCap)),
      ('Circulating', _compact(asset.circulatingSupply)),
      ('ATH', _formatUsd(asset.ath)),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: stats
          .map(
            (s) => Container(
              padding: const EdgeInsets.all(12),
              decoration: context.palette.cardDecoration(radius: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.$1, style: context.typeSecondary(12)),
                  Text(s.$2, style: context.typeCardTitle(14)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  static String _formatUsd(double v) =>
      v >= 1 ? '\$${v.toStringAsFixed(2)}' : '\$${v.toStringAsFixed(4)}';

  static String _compact(double v) {
    if (v <= 0) return '—';
    if (v >= 1e12) return '\$${(v / 1e12).toStringAsFixed(2)}T';
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
    return '\$${v.toStringAsFixed(0)}';
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.side, required this.symbol});

  final String side;
  final String symbol;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  final _controller = TextEditingController(text: '0.01');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.side} ${widget.symbol} · PAPER TRADING'),
      content: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantity'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final qty = double.tryParse(_controller.text.trim()) ?? 0;
            Navigator.pop(context, qty);
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
