import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/charts/lightweight_chart.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/live_tick_price.dart';
import '../../../../models/forex_models.dart';
import '../../../../models/stock_model.dart';
import '../provider/forex_market_provider.dart';

class ForexDetailScreen extends StatefulWidget {
  const ForexDetailScreen({super.key, required this.pairId});

  final String pairId;

  @override
  State<ForexDetailScreen> createState() => _ForexDetailScreenState();
}

class _ForexDetailScreenState extends State<ForexDetailScreen> {
  ForexPairModel? _pair;
  List<CandleModel> _candles = const [];
  String _period = '1D';
  bool _loading = true;
  bool _loadingChart = true;
  String? _error;
  Timer? _quoteTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _quoteTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      unawaited(_refreshQuote());
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final pair = await BullwaveApi.instance.getForexPair(widget.pairId);
      if (!mounted) return;
      setState(() {
        _pair = pair;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Market data is temporarily unavailable. Please try again.';
        _loading = false;
      });
      return;
    }
    await _loadChart(_period);
  }

  Future<void> _refreshQuote() async {
    if (!mounted || _loading) return;
    try {
      final pair = await BullwaveApi.instance.getForexPair(widget.pairId);
      if (!mounted || pair.currentPrice <= 0) return;
      setState(() => _pair = pair);
      context.read<ForexMarketProvider>().tickTape.record(pair.id, pair.currentPrice);
    } catch (_) {}
  }

  Future<void> _loadChart(String period) async {
    setState(() {
      _period = period;
      _loadingChart = true;
    });
    try {
      final chart = await BullwaveApi.instance.getForexChart(widget.pairId, period: period);
      if (!mounted) return;
      setState(() {
        _candles = chart.candles
            .where((c) => c.close.isFinite && c.close > 0 && c.high >= c.low)
            .map(
              (c) => CandleModel(
                time: c.time,
                open: c.open,
                high: c.high,
                low: c.low,
                close: c.close,
                volume: c.volume.isFinite ? c.volume.round() : 0,
              ),
            )
            .toList();
        _loadingChart = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingChart = false);
    }
  }

  Future<void> _trade(String side) async {
    final qty = await _askQty();
    if (qty == null || !mounted) return;
    try {
      await BullwaveApi.instance.placeForexPaperOrder(
        pairId: widget.pairId,
        side: side,
        quantity: qty,
      );
      if (!mounted) return;
      context.read<ForexMarketProvider>().loadPortfolio();
      AppSnackbar.success(context, 'Paper $side placed');
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(context, e.message);
    }
  }

  Future<double?> _askQty() async {
    final controller = TextEditingController(text: '1');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quantity (lots)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text.trim())),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pair = _pair;
    final p = context.palette;
    return Scaffold(
      appBar: CustomAppBar(
        title: pair?.symbol ?? 'Forex',
        actions: [
          if (pair != null)
            IconButton(
              icon: Icon(
                context.watch<ForexMarketProvider>().isInWatchlist(pair.id)
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
              onPressed: () => context.read<ForexMarketProvider>().toggleWatchlist(pair.id),
            ),
        ],
      ),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(16), child: LoadingList(itemCount: 3))
          : pair == null
              ? Center(child: Text(_error ?? 'Pair unavailable'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Text(pair.name, style: context.typeSecondary(14)),
                    const SizedBox(height: 6),
                    LiveTickPrice(
                      value: pair.currentPrice,
                      text: pair.currentPrice >= 10
                          ? pair.currentPrice.toStringAsFixed(3)
                          : pair.currentPrice.toStringAsFixed(5),
                      style: context.typeHeading.copyWith(fontSize: 32),
                      textAlign: TextAlign.start,
                    ),
                    Text(
                      IndexFormatter.formatPercent(pair.change24hPct),
                      style: context.typeLabel(14, pair.isPositive ? p.positive : p.negative),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: _loadingChart
                          ? const Center(child: CircularProgressIndicator())
                          : _candles.isEmpty
                              ? const Center(child: Text('Chart unavailable for this period'))
                              : LightweightMarketChart(
                                  symbol: pair.symbol,
                                  intervalLabel: _period,
                                  candles: _candles,
                                  height: 280,
                                ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: ['1H', '1D', '1W', '1M', '3M']
                          .map(
                            (period) => ChoiceChip(
                              label: Text(period),
                              selected: _period == period,
                              onSelected: (_) => _loadChart(period),
                            ),
                          )
                          .toList(),
                    ),
                    if (_hasOptions) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.forexOptionsPath(_normalizedPairId),
                          ),
                          icon: const Icon(Icons.candlestick_chart_rounded),
                          label: const Text('Option chain · Paper F&O'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _trade('BUY'),
                            style: FilledButton.styleFrom(backgroundColor: p.positive),
                            child: const Text('Paper Buy'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _trade('SELL'),
                            style: FilledButton.styleFrom(backgroundColor: p.negative),
                            child: const Text('Paper Sell'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  String get _normalizedPairId => widget.pairId
      .trim()
      .toLowerCase()
      .replaceAll('/', '')
      .replaceAll('-', '')
      .replaceAll('_', '');

  bool get _hasOptions {
    const listed = {'eurusd', 'gbpusd', 'usdjpy', 'usdinr', 'audusd'};
    return listed.contains(_normalizedPairId) ||
        listed.contains((_pair?.id ?? '').toLowerCase());
  }
}
