import 'dart:math' as math;

import '../../models/stock_model.dart';

List<CandleModel> normalizeCandles(List<CandleModel> candles) {
  final byTime = <int, CandleModel>{};
  for (final candle in candles) {
    byTime[_epochSeconds(candle.time)] = candle;
  }
  final entries = byTime.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return entries.map((entry) => entry.value).toList(growable: false);
}

int _epochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

List<double?> smaValues(List<CandleModel> candles, int period) {
  if (candles.length < period) {
    return List<double?>.filled(candles.length, null);
  }
  final values = List<double?>.filled(candles.length, null);
  var sum = 0.0;
  for (var i = 0; i < candles.length; i++) {
    sum += candles[i].close;
    if (i >= period) sum -= candles[i - period].close;
    if (i >= period - 1) values[i] = sum / period;
  }
  return values;
}

List<double?> emaValues(List<CandleModel> candles, int period) {
  if (candles.isEmpty) return const [];
  final values = List<double?>.filled(candles.length, null);
  final k = 2 / (period + 1);
  var ema = candles.first.close;
  for (var i = 0; i < candles.length; i++) {
    ema = i == 0 ? candles[i].close : (candles[i].close - ema) * k + ema;
    if (i >= period - 1) values[i] = ema;
  }
  return values;
}

({List<double?> upper, List<double?> mid, List<double?> lower}) bollingerBands(
  List<CandleModel> candles, {
  int period = 20,
  double multiplier = 2,
}) {
  final mid = smaValues(candles, period);
  final upper = List<double?>.filled(candles.length, null);
  final lower = List<double?>.filled(candles.length, null);
  for (var i = period - 1; i < candles.length; i++) {
    final mean = mid[i];
    if (mean == null) continue;
    var variance = 0.0;
    for (var j = i - period + 1; j <= i; j++) {
      final d = candles[j].close - mean;
      variance += d * d;
    }
    final std = math.sqrt(variance / period);
    upper[i] = mean + multiplier * std;
    lower[i] = mean - multiplier * std;
  }
  return (upper: upper, mid: mid, lower: lower);
}

String formatChartTime(DateTime time, {bool intraday = false}) {
  if (intraday) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}';
}

bool isIntradayInterval(String label) {
  final lower = label.toLowerCase();
  return lower.endsWith('m') || lower == '1h';
}
