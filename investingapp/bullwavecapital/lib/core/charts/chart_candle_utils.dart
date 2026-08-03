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
