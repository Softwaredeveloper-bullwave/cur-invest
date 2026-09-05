import 'dart:math' as math;

import '../../models/stock_model.dart';

bool _isFiniteCandle(CandleModel candle) {
  return candle.open.isFinite &&
      candle.high.isFinite &&
      candle.low.isFinite &&
      candle.close.isFinite &&
      candle.close > 0 &&
      candle.high >= candle.low;
}

List<CandleModel> normalizeCandles(List<CandleModel> candles) {
  final byTime = <int, CandleModel>{};
  for (final candle in candles) {
    if (!_isFiniteCandle(candle)) continue;
    byTime[_epochSeconds(candle.time)] = candle;
  }
  final entries = byTime.entries.toList()
    ..sort((left, right) => left.key.compareTo(right.key));
  return entries.map((entry) => entry.value).toList(growable: false);
}

int _epochSeconds(DateTime value) =>
    value.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;

/// Maps a UI period/interval label to the candle size when spacing cannot be inferred.
Duration intervalFromLabel(String label) {
  final raw = label.trim();
  switch (raw) {
    case '1m':
      return const Duration(minutes: 1);
    case '5m':
      return const Duration(minutes: 5);
    case '15m':
      return const Duration(minutes: 15);
    case '30m':
      return const Duration(minutes: 30);
    case '1h':
    case '1H':
      return const Duration(hours: 1);
    case '4h':
    case '4H':
      return const Duration(hours: 4);
    case '1d':
    case '1D':
    case '90d':
      return const Duration(days: 1);
    case '1w':
    case '1W':
      return const Duration(days: 7);
    case '1M':
      return const Duration(hours: 1);
    case '3M':
    case '1Y':
    case 'ALL':
      return const Duration(days: 1);
  }
  return const Duration(minutes: 15);
}

/// Median spacing between bars — this is the real candle size, not the chip label.
Duration inferCandleInterval(
  List<CandleModel> candles, {
  String label = '',
}) {
  if (candles.length >= 3) {
    final deltas = <int>[];
    for (var i = 1; i < candles.length; i++) {
      final delta = candles[i]
          .time
          .toUtc()
          .difference(candles[i - 1].time.toUtc())
          .inMilliseconds
          .abs();
      if (delta >= 20 * 1000) deltas.add(delta);
    }
    if (deltas.isNotEmpty) {
      deltas.sort();
      return Duration(milliseconds: deltas[deltas.length ~/ 2]);
    }
  }
  return intervalFromLabel(label);
}

DateTime alignToBucket(DateTime time, Duration interval) {
  final step = interval.inMilliseconds;
  if (step <= 0) return time.toUtc();
  final ms = time.toUtc().millisecondsSinceEpoch;
  final aligned = (ms ~/ step) * step;
  return DateTime.fromMillisecondsSinceEpoch(aligned, isUtc: true);
}

bool intervalShowsClock(Duration interval) =>
    interval < const Duration(hours: 20);

String formatChartTime(
  DateTime time, {
  bool intraday = false,
  Duration? interval,
}) {
  final local = time.toLocal();
  final useClock =
      interval != null ? intervalShowsClock(interval) : intraday;
  if (useClock) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
}

bool isIntradayInterval(String label) {
  return intervalShowsClock(intervalFromLabel(label));
}

String formingCountdownLabel(Duration interval, DateTime bucketUtc) {
  if (!intervalShowsClock(interval)) return 'Live';
  final end = bucketUtc.add(interval);
  var left = end.difference(DateTime.now().toUtc());
  if (left.isNegative) left = Duration.zero;
  final total = left.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

/// Grow / open the current bar from the live last price, like a real trading chart.
List<CandleModel> applyLiveTick(
  List<CandleModel> candles, {
  double? lastPrice,
  String intervalLabel = '',
  DateTime? now,
}) {
  if (candles.isEmpty ||
      lastPrice == null ||
      !lastPrice.isFinite ||
      lastPrice <= 0) {
    return candles;
  }
  final interval = inferCandleInterval(candles, label: intervalLabel);
  final clock = (now ?? DateTime.now()).toUtc();
  final bucket = alignToBucket(clock, interval);
  final last = candles.last;
  final lastBucket = alignToBucket(last.time, interval);

  CandleModel grow(CandleModel bar, DateTime openTime) {
    return CandleModel(
      time: openTime,
      open: bar.open,
      high: math.max(bar.high, lastPrice),
      low: math.min(bar.low, lastPrice),
      close: lastPrice,
      volume: bar.volume,
    );
  }

  if (!lastBucket.isBefore(bucket)) {
    final updated = grow(last, lastBucket);
    if (updated.close == last.close &&
        updated.high == last.high &&
        updated.low == last.low &&
        _epochSeconds(updated.time) == _epochSeconds(last.time)) {
      return candles;
    }
    return [...candles.sublist(0, candles.length - 1), updated];
  }

  final open = last.close > 0 ? last.close : lastPrice;
  return [
    ...candles,
    CandleModel(
      time: bucket,
      open: open,
      high: math.max(open, lastPrice),
      low: math.min(open, lastPrice),
      close: lastPrice,
      volume: 0,
    ),
  ];
}

List<CandleModel> liveChartCandles(
  List<CandleModel> candles, {
  double? lastPrice,
  String intervalLabel = '',
}) {
  return applyLiveTick(
    normalizeCandles(candles),
    lastPrice: lastPrice,
    intervalLabel: intervalLabel,
  );
}
