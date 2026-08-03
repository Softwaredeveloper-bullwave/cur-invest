import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import 'chart_candle_utils.dart';
import 'native_market_chart.dart';

export 'native_market_chart.dart' show NativeMarketChart;

enum MarketChartType { candlestick, line, area }

class LightweightMarketChart extends StatelessWidget {
  final String symbol;
  final String intervalLabel;
  final List<CandleModel> candles;
  final double height;
  final MarketChartType chartType;
  final bool showVolume;
  final bool showSma;
  final double? lastPrice;
  final ValueChanged<CandleModel?>? onCrosshair;

  const LightweightMarketChart({
    super.key,
    required this.symbol,
    required this.intervalLabel,
    required this.candles,
    required this.height,
    this.chartType = MarketChartType.candlestick,
    this.showVolume = true,
    this.showSma = false,
    this.lastPrice,
    this.onCrosshair,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeCandles(candles);

    return NativeMarketChart(
      candles: normalized,
      height: height,
      chartType: chartType,
      showVolume: showVolume,
      showSma: showSma,
      intervalLabel: intervalLabel,
      lastPrice: lastPrice,
      onCrosshair: onCrosshair,
    );
  }
}
