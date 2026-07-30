import 'package:flutter/material.dart';

import '../../../../core/charts/lightweight_chart.dart';
import '../../../../core/charts/tradingview_chart.dart';
import '../../../../models/stock_model.dart';
import 'chart_interval_selector.dart';
import 'premium_chart_toolbar.dart';

/// Interval label shown in UI → backend candle interval.
const stockChartIntervals = <({String label, String apiInterval})>[
  (label: '1m', apiInterval: '1m'),
  (label: '5m', apiInterval: '5m'),
  (label: '30m', apiInterval: '30m'),
  (label: '1H', apiInterval: '1h'),
  (label: '1D', apiInterval: '1d'),
  (label: '1M', apiInterval: '90d'),
];

class StockDetailChart extends StatefulWidget {
  final String symbol;
  final String exchange;
  final List<CandleModel> candles;
  final bool isLoading;
  final String selectedLabel;
  final ValueChanged<String> onIntervalSelected;

  const StockDetailChart({
    super.key,
    required this.symbol,
    this.exchange = 'NSE',
    required this.candles,
    required this.isLoading,
    required this.selectedLabel,
    required this.onIntervalSelected,
  });

  @override
  State<StockDetailChart> createState() => _StockDetailChartState();
}

class _StockDetailChartState extends State<StockDetailChart> {
  MarketChartType _chartType = MarketChartType.candlestick;
  bool _showVolume = true;
  bool _showSma = false;

  String get _apiInterval {
    for (final item in stockChartIntervals) {
      if (item.label == widget.selectedLabel) return item.apiInterval;
    }
    return '1d';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth >= 700
            ? 420.0
            : constraints.maxWidth < 380
            ? 280.0
            : 330.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumChartToolbar(
              chartType: _chartType,
              onChartTypeChanged: (value) => setState(() => _chartType = value),
              showVolume: _showVolume,
              onVolumeChanged: (value) => setState(() => _showVolume = value),
              showSma: _showSma,
              onSmaChanged: (value) => setState(() => _showSma = value),
              onFullscreen: _openFullscreen,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: TradingViewChart(
                symbol: widget.symbol,
                exchange: widget.exchange,
                intervalLabel: widget.selectedLabel,
                apiInterval: _apiInterval,
                fallbackCandles: widget.candles,
                isLoading: widget.isLoading,
                height: chartHeight,
                chartType: _chartType,
                showVolume: _showVolume,
                showSma: _showSma,
              ),
            ),
            const SizedBox(height: 16),
            ChartIntervalSelector(
              selectedLabel: widget.selectedLabel,
              onSelected: widget.onIntervalSelected,
            ),
          ],
        );
      },
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenStockChart(
          symbol: widget.symbol,
          exchange: widget.exchange,
          intervalLabel: widget.selectedLabel,
          apiInterval: _apiInterval,
          candles: widget.candles,
          initialType: _chartType,
          initialShowVolume: _showVolume,
          initialShowSma: _showSma,
        ),
      ),
    );
  }
}

class _FullscreenStockChart extends StatefulWidget {
  final String symbol;
  final String exchange;
  final String intervalLabel;
  final String apiInterval;
  final List<CandleModel> candles;
  final MarketChartType initialType;
  final bool initialShowVolume;
  final bool initialShowSma;

  const _FullscreenStockChart({
    required this.symbol,
    required this.exchange,
    required this.intervalLabel,
    required this.apiInterval,
    required this.candles,
    required this.initialType,
    required this.initialShowVolume,
    required this.initialShowSma,
  });

  @override
  State<_FullscreenStockChart> createState() => _FullscreenStockChartState();
}

class _FullscreenStockChartState extends State<_FullscreenStockChart> {
  late MarketChartType _chartType = widget.initialType;
  late bool _showVolume = widget.initialShowVolume;
  late bool _showSma = widget.initialShowSma;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050503),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050503),
        foregroundColor: Colors.white,
        title: Text('${widget.symbol} · ${widget.intervalLabel}'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Column(
            children: [
              PremiumChartToolbar(
                chartType: _chartType,
                onChartTypeChanged: (value) =>
                    setState(() => _chartType = value),
                showVolume: _showVolume,
                onVolumeChanged: (value) => setState(() => _showVolume = value),
                showSma: _showSma,
                onSmaChanged: (value) => setState(() => _showSma = value),
                onFullscreen: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: TradingViewChart(
                      symbol: widget.symbol,
                      exchange: widget.exchange,
                      intervalLabel: widget.intervalLabel,
                      apiInterval: widget.apiInterval,
                      fallbackCandles: widget.candles,
                      height: constraints.maxHeight,
                      chartType: _chartType,
                      showVolume: _showVolume,
                      showSma: _showSma,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
