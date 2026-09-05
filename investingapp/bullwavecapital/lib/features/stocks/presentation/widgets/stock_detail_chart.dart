import 'package:flutter/material.dart';

import '../../../../core/charts/lightweight_chart.dart';
import '../../../../core/charts/chart_candle_utils.dart';
import '../../../../core/charts/tradingview_chart.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import 'chart_interval_selector.dart';
import 'dhan_chart_toolbar.dart';
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

const Color _dhanChartBg = Color(0xFF0B0E11);
const Color _dhanChartBorder = Color(0xFF1E2329);

class StockDetailChart extends StatefulWidget {
  final String symbol;
  final String exchange;
  final List<CandleModel> candles;
  final bool isLoading;
  final String selectedLabel;
  final ValueChanged<String> onIntervalSelected;
  final double? lastPrice;

  const StockDetailChart({
    super.key,
    required this.symbol,
    this.exchange = 'NSE',
    required this.candles,
    required this.isLoading,
    required this.selectedLabel,
    required this.onIntervalSelected,
    this.lastPrice,
  });

  @override
  State<StockDetailChart> createState() => _StockDetailChartState();
}

class _StockDetailChartState extends State<StockDetailChart> {
  MarketChartType _chartType = MarketChartType.candlestick;
  bool _showVolume = true;
  bool _showSma = false;
  CandleModel? _crosshairCandle;

  String get _apiInterval {
    for (final item in stockChartIntervals) {
      if (item.label == widget.selectedLabel) return item.apiInterval;
    }
    return '1d';
  }

  CandleModel? get _displayCandle {
    if (_crosshairCandle != null) return _crosshairCandle;
    final series = liveChartCandles(
      widget.candles,
      lastPrice: widget.lastPrice,
      intervalLabel: widget.selectedLabel,
    );
    if (series.isEmpty) return null;
    return series.last;
  }

  String _formatVol(int vol) {
    if (vol >= 10000000) return '${(vol / 10000000).toStringAsFixed(2)}Cr';
    if (vol >= 100000) return '${(vol / 100000).toStringAsFixed(2)}L';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(1)}K';
    return vol.toString();
  }

  @override
  Widget build(BuildContext context) {
    final candle = _displayCandle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth >= 700
            ? 340.0
            : constraints.maxWidth < 380
            ? 240.0
            : 290.0;

        return Container(
          decoration: BoxDecoration(
            color: _dhanChartBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _dhanChartBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ChartIntervalSelector(
                        selectedLabel: widget.selectedLabel,
                        onSelected: widget.onIntervalSelected,
                        dhanStyle: true,
                      ),
                    ),
                    IconButton(
                      onPressed: _openFullscreen,
                      tooltip: 'Fullscreen chart',
                      icon: const Icon(
                        Icons.open_in_full_rounded,
                        size: 18,
                        color: Color(0xFF8B949E),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              DhanChartToolbar(
                chartType: _chartType,
                onChartTypeChanged: (v) => setState(() => _chartType = v),
                showVolume: _showVolume,
                onVolumeChanged: (v) => setState(() => _showVolume = v),
                showSma: _showSma,
                onSmaChanged: (v) => setState(() => _showSma = v),
              ),
              ChartOhlcStrip(
                open: candle != null
                    ? IndexFormatter.format(candle.open)
                    : null,
                high: candle != null
                    ? IndexFormatter.format(candle.high)
                    : null,
                low: candle != null ? IndexFormatter.format(candle.low) : null,
                close: candle != null
                    ? IndexFormatter.format(candle.close)
                    : null,
                volume: candle != null ? _formatVol(candle.volume) : null,
                isBullish: candle?.isBullish ?? true,
              ),
              SizedBox(
                height: chartHeight,
                child: Stack(
                  children: [
                    TradingViewChart(
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
                      lastPrice: widget.lastPrice,
                      onCrosshair: (c) => setState(() => _crosshairCandle = c),
                    ),
                    if (widget.isLoading)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x880B0E11),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
          lastPrice: widget.lastPrice,
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
  final double? lastPrice;
  final MarketChartType initialType;
  final bool initialShowVolume;
  final bool initialShowSma;

  const _FullscreenStockChart({
    required this.symbol,
    required this.exchange,
    required this.intervalLabel,
    required this.apiInterval,
    required this.candles,
    this.lastPrice,
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
      backgroundColor: _dhanChartBg,
      appBar: AppBar(
        backgroundColor: _dhanChartBg,
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
                      lastPrice: widget.lastPrice,
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
