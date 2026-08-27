import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/forex_models.dart';

/// Live ECB rates used only when Django `/forex/` is not on the server yet.
class ForexLiveFallback {
  ForexLiveFallback._();

  static const _pairs = <(String, String, String, String, String)>[
    ('eurusd', 'EUR', 'USD', 'Euro / US Dollar', 'Majors'),
    ('gbpusd', 'GBP', 'USD', 'British Pound / US Dollar', 'Majors'),
    ('usdjpy', 'USD', 'JPY', 'US Dollar / Japanese Yen', 'Majors'),
    ('usdchf', 'USD', 'CHF', 'US Dollar / Swiss Franc', 'Majors'),
    ('audusd', 'AUD', 'USD', 'Australian Dollar / US Dollar', 'Majors'),
    ('usdcad', 'USD', 'CAD', 'US Dollar / Canadian Dollar', 'Majors'),
    ('nzdusd', 'NZD', 'USD', 'New Zealand Dollar / US Dollar', 'Majors'),
    ('eurgbp', 'EUR', 'GBP', 'Euro / British Pound', 'Crosses'),
    ('eurjpy', 'EUR', 'JPY', 'Euro / Japanese Yen', 'Crosses'),
    ('gbpjpy', 'GBP', 'JPY', 'British Pound / Japanese Yen', 'Crosses'),
    ('eurchf', 'EUR', 'CHF', 'Euro / Swiss Franc', 'Crosses'),
    ('audjpy', 'AUD', 'JPY', 'Australian Dollar / Japanese Yen', 'Crosses'),
    ('usdinr', 'USD', 'INR', 'US Dollar / Indian Rupee', 'Exotics'),
    ('eurinr', 'EUR', 'INR', 'Euro / Indian Rupee', 'Exotics'),
    ('gbpinr', 'GBP', 'INR', 'British Pound / Indian Rupee', 'Exotics'),
    ('usdcny', 'USD', 'CNY', 'US Dollar / Chinese Yuan', 'Exotics'),
    ('usdtry', 'USD', 'TRY', 'US Dollar / Turkish Lira', 'Exotics'),
    ('usdzar', 'USD', 'ZAR', 'US Dollar / South African Rand', 'Exotics'),
  ];

  static Future<({ForexOverviewModel overview, List<ForexPairModel> pairs})> load() async {
    final response = await http
        .get(Uri.parse('https://api.frankfurter.app/latest?from=USD'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('FX rates unavailable');
    }
    final data = jsonDecode(response.body);
    if (data is! Map) throw Exception('FX rates unavailable');
    final rates = <String, double>{'USD': 1};
    final raw = data['rates'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final n = value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
        rates['$key'.toUpperCase()] = n;
      });
    }

    double rate(String base, String quote) {
      final ub = rates[base] ?? 0;
      final uq = rates[quote] ?? 0;
      if (ub <= 0 || uq <= 0) return 0;
      return uq / ub;
    }

    final pairs = _pairs.map((row) {
      final price = rate(row.$2, row.$3);
      return ForexPairModel(
        id: row.$1,
        symbol: '${row.$2}/${row.$3}',
        name: row.$4,
        baseCurrency: row.$2,
        quoteCurrency: row.$3,
        category: row.$5,
        currentPrice: price,
      );
    }).where((p) => p.currentPrice > 0).toList();

    final majors = pairs.where((p) => p.category == 'Majors').toList();
    final overview = ForexOverviewModel(
      totalPairs: pairs.length,
      provider: 'ecb',
      trending: majors.take(5).toList(),
      majors: majors,
      topGainers: majors.take(5).toList(),
      topLosers: majors.reversed.take(5).toList(),
    );
    return (overview: overview, pairs: pairs);
  }
}
