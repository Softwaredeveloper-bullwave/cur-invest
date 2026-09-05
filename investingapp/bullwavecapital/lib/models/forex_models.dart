dynamic _pick(Map<String, dynamic> json, String camel, String snake) =>
    json[camel] ?? json[snake];

double _num(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? 0;
  return 0;
}

int _int(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt() ?? 0;
  return 0;
}

DateTime _date(dynamic v) {
  if (v == null) return DateTime.now();
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

DateTime _chartTime(dynamic v) {
  final ms = _int(v);
  if (ms <= 0) return DateTime.now();
  if (ms < 100000000000) return DateTime.fromMillisecondsSinceEpoch(ms * 1000);
  return DateTime.fromMillisecondsSinceEpoch(ms);
}

List<double> _sparkline(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => _num(e)).toList();
}

class ForexPairModel {
  const ForexPairModel({
    required this.id,
    required this.symbol,
    required this.name,
    this.baseCurrency = '',
    this.quoteCurrency = '',
    this.category = 'Majors',
    this.currentPrice = 0,
    this.change24hPct = 0,
    this.change24h = 0,
    this.high24h = 0,
    this.low24h = 0,
    this.sparkline = const [],
  });

  final String id;
  final String symbol;
  final String name;
  final String baseCurrency;
  final String quoteCurrency;
  final String category;
  final double currentPrice;
  final double change24hPct;
  final double change24h;
  final double high24h;
  final double low24h;
  final List<double> sparkline;

  bool get isPositive => change24hPct >= 0;

  factory ForexPairModel.fromJson(Map<String, dynamic> json) => ForexPairModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        symbol: (_pick(json, 'symbol', 'symbol') ?? '').toString().toUpperCase(),
        name: (_pick(json, 'name', 'name') ?? '').toString(),
        baseCurrency: (_pick(json, 'baseCurrency', 'base_currency') ?? '').toString(),
        quoteCurrency: (_pick(json, 'quoteCurrency', 'quote_currency') ?? '').toString(),
        category: (_pick(json, 'category', 'category') ?? 'Majors').toString(),
        currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
        change24hPct: _num(_pick(json, 'change24hPct', 'price_change_percentage_24h')),
        change24h: _num(_pick(json, 'change24h', 'price_change_24h')),
        high24h: _num(_pick(json, 'high24h', 'high_24h')),
        low24h: _num(_pick(json, 'low24h', 'low_24h')),
        sparkline: _sparkline(_pick(json, 'sparkline7d', 'sparkline_7d')),
      );
}

List<ForexPairModel> parseForexPairList(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => ForexPairModel.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

class ForexOverviewModel {
  const ForexOverviewModel({
    this.totalPairs = 0,
    this.provider = '',
    this.stale = false,
    this.trending = const [],
    this.majors = const [],
    this.topGainers = const [],
    this.topLosers = const [],
  });

  final int totalPairs;
  final String provider;
  final bool stale;
  final List<ForexPairModel> trending;
  final List<ForexPairModel> majors;
  final List<ForexPairModel> topGainers;
  final List<ForexPairModel> topLosers;

  factory ForexOverviewModel.fromJson(Map<String, dynamic> json) => ForexOverviewModel(
        totalPairs: _int(_pick(json, 'totalPairs', 'total_pairs')),
        provider: (_pick(json, 'provider', 'provider') ?? '').toString(),
        stale: _pick(json, 'stale', 'stale') == true,
        trending: parseForexPairList(json['trending']),
        majors: parseForexPairList(json['majors']),
        topGainers: parseForexPairList(json['top_gainers'] ?? json['topGainers']),
        topLosers: parseForexPairList(json['top_losers'] ?? json['topLosers']),
      );
}

class ForexWatchlistItemModel {
  const ForexWatchlistItemModel({
    required this.id,
    required this.pairId,
    this.symbol = '',
    this.name = '',
    this.currentPrice = 0,
    this.change24hPct = 0,
  });

  final String id;
  final String pairId;
  final String symbol;
  final String name;
  final double currentPrice;
  final double change24hPct;

  factory ForexWatchlistItemModel.fromJson(Map<String, dynamic> json) =>
      ForexWatchlistItemModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        pairId: (_pick(json, 'pairId', 'pair_id') ??
                _pick(json, 'assetId', 'asset_id') ??
                '')
            .toString(),
        symbol: (_pick(json, 'symbol', 'symbol') ?? '').toString(),
        name: (_pick(json, 'name', 'name') ?? '').toString(),
        currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
        change24hPct: _num(_pick(json, 'change24hPct', 'price_change_percentage_24h')),
      );
}

class ForexNewsModel {
  const ForexNewsModel({
    required this.id,
    required this.title,
    this.summary = '',
    this.imageUrl = '',
    this.source = '',
    required this.publishedAt,
    this.category = '',
    this.relatedPairs = const [],
    this.externalUrl = '',
  });

  final String id;
  final String title;
  final String summary;
  final String imageUrl;
  final String source;
  final DateTime publishedAt;
  final String category;
  final List<String> relatedPairs;
  final String externalUrl;

  factory ForexNewsModel.fromJson(Map<String, dynamic> json) => ForexNewsModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        title: (_pick(json, 'title', 'title') ?? '').toString(),
        summary: (_pick(json, 'summary', 'summary') ?? '').toString(),
        imageUrl: (_pick(json, 'imageUrl', 'image_url') ?? '').toString(),
        source: (_pick(json, 'source', 'source') ?? '').toString(),
        publishedAt: _date(_pick(json, 'publishedAt', 'published_at')),
        category: (_pick(json, 'category', 'category') ?? '').toString(),
        relatedPairs: (json['relatedPairs'] as List<dynamic>? ??
                json['related_pairs'] as List<dynamic>? ??
                const [])
            .map((e) => e.toString())
            .toList(),
        externalUrl: (_pick(json, 'externalUrl', 'external_url') ?? '').toString(),
      );
}

class ForexNewsResponse {
  const ForexNewsResponse({required this.results, this.categories = const []});

  final List<ForexNewsModel> results;
  final List<String> categories;

  factory ForexNewsResponse.fromJson(Map<String, dynamic> json) => ForexNewsResponse(
        results: (json['results'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ForexNewsModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      );
}

class ForexHoldingModel {
  const ForexHoldingModel({
    required this.pairId,
    required this.symbol,
    this.name = '',
    this.quantity = 0,
    this.avgPrice = 0,
    this.currentPrice = 0,
    this.currentValue = 0,
    this.profitLoss = 0,
  });

  final String pairId;
  final String symbol;
  final String name;
  final double quantity;
  final double avgPrice;
  final double currentPrice;
  final double currentValue;
  final double profitLoss;

  factory ForexHoldingModel.fromJson(Map<String, dynamic> json) => ForexHoldingModel(
        pairId: (_pick(json, 'pairId', 'pair_id') ?? '').toString(),
        symbol: (_pick(json, 'symbol', 'symbol') ?? '').toString(),
        name: (_pick(json, 'name', 'name') ?? '').toString(),
        quantity: _num(_pick(json, 'quantity', 'quantity')),
        avgPrice: _num(_pick(json, 'avgPrice', 'avg_price')),
        currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
        currentValue: _num(_pick(json, 'currentValue', 'current_value')),
        profitLoss: _num(_pick(json, 'profitLoss', 'profit_loss')),
      );
}

class ForexPortfolioModel {
  const ForexPortfolioModel({
    this.environment = 'PAPER TRADING',
    this.walletBalance = 0,
    this.investedAmount = 0,
    this.currentValue = 0,
    this.totalPortfolioValue = 0,
    this.profitLoss = 0,
    this.profitLossPercent = 0,
    this.usdInrRate = 83.5,
    this.displayCurrency = 'USD',
    this.holdings = const [],
  });

  final String environment;
  final double walletBalance;
  final double investedAmount;
  final double currentValue;
  final double totalPortfolioValue;
  final double profitLoss;
  final double profitLossPercent;
  final double usdInrRate;
  final String displayCurrency;
  final List<ForexHoldingModel> holdings;

  bool get isPositive => profitLoss >= 0;

  factory ForexPortfolioModel.fromJson(Map<String, dynamic> json) => ForexPortfolioModel(
        environment: (_pick(json, 'environment', 'environment') as String?) ?? 'PAPER TRADING',
        walletBalance: _num(_pick(json, 'walletBalance', 'wallet_balance')),
        investedAmount: _num(_pick(json, 'investedAmount', 'invested_amount')),
        currentValue: _num(_pick(json, 'currentValue', 'current_value')),
        totalPortfolioValue: _num(_pick(json, 'totalPortfolioValue', 'total_portfolio_value')),
        profitLoss: _num(_pick(json, 'profitLoss', 'profit_loss')),
        profitLossPercent: _num(_pick(json, 'profitLossPercent', 'profit_loss_percent')),
        usdInrRate: _num(_pick(json, 'usdInrRate', 'usd_inr_rate')) > 0
            ? _num(_pick(json, 'usdInrRate', 'usd_inr_rate'))
            : 83.5,
        displayCurrency:
            (_pick(json, 'displayCurrency', 'display_currency') as String?) ?? 'USD',
        holdings: (json['holdings'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => ForexHoldingModel.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class ForexChartModel {
  const ForexChartModel({
    required this.pairId,
    required this.period,
    this.candles = const [],
  });

  final String pairId;
  final String period;
  final List<ForexCandlePoint> candles;

  factory ForexChartModel.fromJson(Map<String, dynamic> json) {
    final raw = json['candles'];
    final candles = <ForexCandlePoint>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          candles.add(ForexCandlePoint.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return ForexChartModel(
      pairId: (_pick(json, 'pairId', 'pair_id') ?? _pick(json, 'assetId', 'asset_id') ?? '').toString(),
      period: (_pick(json, 'period', 'period') ?? '1D').toString(),
      candles: candles,
    );
  }
}

class ForexCandlePoint {
  const ForexCandlePoint({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  factory ForexCandlePoint.fromJson(Map<String, dynamic> json) => ForexCandlePoint(
        time: _chartTime(json['t'] ?? json['time']),
        open: _num(json['o'] ?? json['open']),
        high: _num(json['h'] ?? json['high']),
        low: _num(json['l'] ?? json['low']),
        close: _num(json['c'] ?? json['close']),
        volume: _num(json['v'] ?? json['volume']),
      );
}
