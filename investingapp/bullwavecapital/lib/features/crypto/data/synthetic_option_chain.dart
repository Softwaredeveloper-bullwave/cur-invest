import 'dart:math';

import '../../../../models/stock_model.dart';

class _CatalogRow {
  const _CatalogRow({
    required this.id,
    required this.symbol,
    required this.name,
    required this.vol,
    required this.fallback,
  });

  final String id;
  final String symbol;
  final String name;
  final double vol;
  final double fallback;
}

const _cryptoCatalog = {
  'bitcoin': _CatalogRow(
    id: 'bitcoin',
    symbol: 'BTC',
    name: 'Bitcoin',
    vol: 0.08,
    fallback: 97000,
  ),
  'ethereum': _CatalogRow(
    id: 'ethereum',
    symbol: 'ETH',
    name: 'Ethereum',
    vol: 0.09,
    fallback: 3500,
  ),
  'solana': _CatalogRow(
    id: 'solana',
    symbol: 'SOL',
    name: 'Solana',
    vol: 0.11,
    fallback: 145,
  ),
  'ripple': _CatalogRow(
    id: 'ripple',
    symbol: 'XRP',
    name: 'XRP',
    vol: 0.1,
    fallback: 0.62,
  ),
  'binancecoin': _CatalogRow(
    id: 'binancecoin',
    symbol: 'BNB',
    name: 'BNB',
    vol: 0.08,
    fallback: 580,
  ),
};

const _cryptoAliases = {
  'btc': 'bitcoin',
  'eth': 'ethereum',
  'sol': 'solana',
  'xrp': 'ripple',
  'bnb': 'binancecoin',
};

const _forexCatalog = {
  'eurusd': _CatalogRow(
    id: 'eurusd',
    symbol: 'EUR/USD',
    name: 'Euro / US Dollar',
    vol: 0.012,
    fallback: 1.16,
  ),
  'gbpusd': _CatalogRow(
    id: 'gbpusd',
    symbol: 'GBP/USD',
    name: 'British Pound / US Dollar',
    vol: 0.013,
    fallback: 1.31,
  ),
  'usdjpy': _CatalogRow(
    id: 'usdjpy',
    symbol: 'USD/JPY',
    name: 'US Dollar / Japanese Yen',
    vol: 0.011,
    fallback: 149.5,
  ),
  'usdinr': _CatalogRow(
    id: 'usdinr',
    symbol: 'USD/INR',
    name: 'US Dollar / Indian Rupee',
    vol: 0.01,
    fallback: 83.5,
  ),
  'audusd': _CatalogRow(
    id: 'audusd',
    symbol: 'AUD/USD',
    name: 'Australian Dollar / US Dollar',
    vol: 0.014,
    fallback: 0.66,
  ),
};

String canonicalCryptoId(String raw) {
  final id = raw.trim().toLowerCase();
  return _cryptoAliases[id] ?? id;
}

String canonicalForexId(String raw) {
  return raw.trim().toLowerCase().replaceAll('/', '').replaceAll('-', '').replaceAll('_', '');
}

_CatalogRow? cryptoCatalogRow(String raw) =>
    _cryptoCatalog[canonicalCryptoId(raw)];

_CatalogRow? forexCatalogRow(String raw) =>
    _forexCatalog[canonicalForexId(raw)];

List<DateTime> fridayExpiries({int count = 4}) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  final expiries = <DateTime>[];
  var d = start;
  while (expiries.length < count && d.difference(start).inDays <= 60) {
    if (d.weekday == DateTime.friday && !d.isBefore(start)) {
      expiries.add(d);
    }
    d = d.add(const Duration(days: 1));
  }
  if (expiries.isEmpty) {
    final ahead = (DateTime.friday - start.weekday) % 7;
    expiries.add(start.add(Duration(days: ahead == 0 ? 7 : ahead)));
  }
  return expiries.take(count).toList();
}

double strikeStep(double spot) {
  if (spot >= 20000) return 500;
  if (spot >= 5000) return 100;
  if (spot >= 1000) return 25;
  if (spot >= 200) return 5;
  if (spot >= 50) return 1;
  if (spot >= 10) return 0.25;
  if (spot >= 2) return 0.05;
  if (spot >= 0.5) return 0.005;
  return 0.0005;
}

OptionChainResponse buildSyntheticOptionChain({
  required String symbol,
  required double spot,
  required String tradeUnderlying,
  required double volFactor,
  DateTime? expiry,
  int numStrikes = 21,
}) {
  final expiries = fridayExpiries();
  var selected = expiry ?? expiries.first;
  selected = DateTime(selected.year, selected.month, selected.day);
  final expiryDates = [
    for (final e in expiries) e.toIso8601String().substring(0, 10),
  ];
  final selectedIso = selected.toIso8601String().substring(0, 10);
  if (!expiryDates.contains(selectedIso)) {
    expiryDates.add(selectedIso);
    expiryDates.sort();
  }

  final step = strikeStep(spot);
  final atm = (spot / step).round() * step;
  final half = numStrikes ~/ 2;
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final days = max(selected.difference(todayDate).inDays, 1);
  final decimals = spot < 10
      ? 6
      : spot < 200
          ? 4
          : 2;
  final minLtp = pow(10, -decimals).toDouble();
  final contracts = <OptionContractModel>[];

  for (var i = 0; i < numStrikes; i++) {
    final strike = double.parse((atm + (i - half) * step).toStringAsFixed(decimals));
    if (strike <= 0) continue;
    final moneyness = (spot - strike).abs() / max(spot, 1e-9);
    final baseOi = (180000 * exp(-moneyness * 5)).round();
    for (final type in const ['CE', 'PE']) {
      final intrinsic = type == 'CE' ? max(0.0, spot - strike) : max(0.0, strike - spot);
      final timeVal =
          spot * volFactor * sqrt(days / 365) * exp(-moneyness * 4);
      final ltp = max(
        double.parse((intrinsic + timeVal).toStringAsFixed(decimals)),
        minLtp,
      );
      final change = double.parse(
        (ltp * 0.02 * (type == 'CE' ? 1 : -1)).toStringAsFixed(decimals),
      );
      contracts.add(
        OptionContractModel(
          symbol: symbol,
          underlyingId: tradeUnderlying,
          strike: strike,
          type: type,
          ltp: ltp,
          change: change,
          oi: baseOi + ((strike - atm).abs() < step / 2 ? 20000 : 0),
          volume: (baseOi * 0.12).round(),
          expiry: selected,
        ),
      );
    }
  }

  return OptionChainResponse(
    symbol: symbol,
    underlyingValue: double.parse(spot.toStringAsFixed(decimals)),
    expiryDates: expiryDates,
    selectedExpiry: selectedIso,
    contracts: contracts,
  );
}

OptionChainResponse buildCryptoFallbackChain(String assetId, {double? spot, DateTime? expiry}) {
  final row = cryptoCatalogRow(assetId) ?? _cryptoCatalog['bitcoin']!;
  final px = (spot != null && spot > 0) ? spot : row.fallback;
  return buildSyntheticOptionChain(
    symbol: row.symbol,
    spot: px,
    tradeUnderlying: row.id,
    volFactor: row.vol,
    expiry: expiry,
  );
}

OptionChainResponse buildForexFallbackChain(String pairId, {double? spot, DateTime? expiry}) {
  final row = forexCatalogRow(pairId) ?? _forexCatalog['eurusd']!;
  final px = (spot != null && spot > 0) ? spot : row.fallback;
  return buildSyntheticOptionChain(
    symbol: row.symbol,
    spot: px,
    tradeUnderlying: row.id,
    volFactor: row.vol,
    expiry: expiry,
  );
}
