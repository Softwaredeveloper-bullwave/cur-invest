import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import 'lightweight_chart_platform_stub.dart'
    if (dart.library.html) 'lightweight_chart_platform_web.dart'
    if (dart.library.io) 'lightweight_chart_platform_mobile.dart';

enum MarketChartType { candlestick, line, area }

class LightweightMarketChart extends StatelessWidget {
  final String symbol;
  final String intervalLabel;
  final List<CandleModel> candles;
  final double height;
  final MarketChartType chartType;
  final bool showVolume;
  final bool showSma;

  const LightweightMarketChart({
    super.key,
    required this.symbol,
    required this.intervalLabel,
    required this.candles,
    required this.height,
    this.chartType = MarketChartType.candlestick,
    this.showVolume = true,
    this.showSma = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = _normalizeCandles(candles);
    final payload = <String, dynamic>{
      'symbol': symbol.toUpperCase(),
      'interval': intervalLabel,
      'theme': isDark ? 'dark' : 'light',
      'chartType': chartType.name,
      'showVolume': showVolume,
      'showSma': showSma,
      'candles': normalized
          .map(
            (candle) => {
              'time': _epochSeconds(candle.time),
              'open': candle.open,
              'high': candle.high,
              'low': candle.low,
              'close': candle.close,
            },
          )
          .toList(growable: false),
      'volume': normalized
          .map(
            (candle) => {
              'time': _epochSeconds(candle.time),
              'value': candle.volume,
              'color': candle.isBullish
                  ? 'rgba(0,200,83,.35)'
                  : 'rgba(239,83,80,.35)',
            },
          )
          .toList(growable: false),
      'sma20': _sma(normalized, 20),
      'sma50': _sma(normalized, 50),
    };

    return LightweightChartPlatformView(
      payloadJson: jsonEncode(payload),
      candles: normalized,
      height: height,
    );
  }
}

int _epochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

List<CandleModel> _normalizeCandles(List<CandleModel> candles) {
  final byTime = <int, CandleModel>{};
  for (final candle in candles) {
    byTime[_epochSeconds(candle.time)] = candle;
  }
  final entries = byTime.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return entries.map((entry) => entry.value).toList(growable: false);
}

List<Map<String, dynamic>> _sma(List<CandleModel> candles, int period) {
  if (candles.length < period) return const [];
  final points = <Map<String, dynamic>>[];
  var sum = 0.0;
  for (var index = 0; index < candles.length; index++) {
    sum += candles[index].close;
    if (index >= period) sum -= candles[index - period].close;
    if (index >= period - 1) {
      points.add({
        'time': _epochSeconds(candles[index].time),
        'value': sum / period,
      });
    }
  }
  return points;
}
