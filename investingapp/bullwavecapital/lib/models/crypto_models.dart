import 'package:flutter/foundation.dart';

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
  if (v is String) {
    final parsed = int.tryParse(v.trim());
    if (parsed != null) return parsed;
    return double.tryParse(v.trim())?.toInt() ?? 0;
  }
  return 0;
}

DateTime _date(dynamic v) {
  if (v == null) return DateTime.now();
  final s = v.toString().trim();
  if (s.isEmpty) return DateTime.now();
  try {
    return DateTime.parse(s).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}

List<double> _sparkline(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => _num(e)).toList();
}

class UserMarketPreferenceModel {
  const UserMarketPreferenceModel({
    required this.indianMarketEnabled,
    required this.cryptoMarketEnabled,
    required this.activeMarket,
    required this.hasCompletedSelection,
  });

  final bool indianMarketEnabled;
  final bool cryptoMarketEnabled;
  final String activeMarket;
  final bool hasCompletedSelection;

  bool get isCryptoActive => activeMarket == 'crypto';

  factory UserMarketPreferenceModel.fromJson(Map<String, dynamic> json) =>
      UserMarketPreferenceModel(
        indianMarketEnabled:
            _pick(json, 'indianMarketEnabled', 'indian_market_enabled') as bool? ?? true,
        cryptoMarketEnabled:
            _pick(json, 'cryptoMarketEnabled', 'crypto_market_enabled') as bool? ?? false,
        activeMarket:
            (_pick(json, 'activeMarket', 'active_market') as String?) ?? 'indian',
        hasCompletedSelection:
            _pick(json, 'hasCompletedSelection', 'has_completed_selection') as bool? ??
                false,
      );

  Map<String, dynamic> toJson() => {
        'indian_market_enabled': indianMarketEnabled,
        'crypto_market_enabled': cryptoMarketEnabled,
        'active_market': activeMarket,
        'has_completed_selection': hasCompletedSelection,
      };
}

class CryptoAssetModel {
  const CryptoAssetModel({
    required this.id,
    required this.symbol,
    required this.name,
    this.imageUrl = '',
    this.currentPrice = 0,
    this.change24hPct = 0,
    this.change24h = 0,
    this.high24h = 0,
    this.low24h = 0,
    this.volume = 0,
    this.marketCap = 0,
    this.marketCapRank = 0,
    this.sparkline = const [],
    this.description = '',
    this.currency = 'usd',
    this.circulatingSupply = 0,
    this.totalSupply = 0,
    this.maxSupply = 0,
    this.ath = 0,
    this.atl = 0,
  });

  final String id;
  final String symbol;
  final String name;
  final String imageUrl;
  final double currentPrice;
  final double change24hPct;
  final double change24h;
  final double high24h;
  final double low24h;
  final double volume;
  final double marketCap;
  final int marketCapRank;
  final List<double> sparkline;
  final String description;
  final String currency;
  final double circulatingSupply;
  final double totalSupply;
  final double maxSupply;
  final double ath;
  final double atl;

  bool get isPositive => change24hPct >= 0;

  factory CryptoAssetModel.fromJson(Map<String, dynamic> json) {
    final sparkRaw = _pick(json, 'sparkline7d', 'sparkline_7d') ??
        _pick(json, 'sparkline', 'sparkline');
    return CryptoAssetModel(
      id: (_pick(json, 'id', 'id') ?? '').toString(),
      symbol: ((_pick(json, 'symbol', 'symbol') as String?) ?? '').toUpperCase(),
      name: (_pick(json, 'name', 'name') as String?) ?? '',
      imageUrl: (_pick(json, 'imageUrl', 'image_url') as String?) ?? '',
      currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
      change24hPct: _num(
        _pick(json, 'change24hPct', 'price_change_percentage_24h') ??
            _pick(json, 'priceChangePercentage24h', 'price_change_percentage_24h'),
      ),
      change24h: _num(_pick(json, 'change24h', 'price_change_24h')),
      high24h: _num(_pick(json, 'high24h', 'high_24h')),
      low24h: _num(_pick(json, 'low24h', 'low_24h')),
      volume: _num(_pick(json, 'volume', 'total_volume')),
      marketCap: _num(_pick(json, 'marketCap', 'market_cap')),
      marketCapRank: _int(_pick(json, 'marketCapRank', 'market_cap_rank')),
      sparkline: _sparkline(sparkRaw),
      description: (_pick(json, 'description', 'description') as String?) ?? '',
      currency: (_pick(json, 'currency', 'currency') as String?) ?? 'usd',
      circulatingSupply: _num(_pick(json, 'circulatingSupply', 'circulating_supply')),
      totalSupply: _num(_pick(json, 'totalSupply', 'total_supply')),
      maxSupply: _num(_pick(json, 'maxSupply', 'max_supply')),
      ath: _num(_pick(json, 'ath', 'ath')),
      atl: _num(_pick(json, 'atl', 'atl')),
    );
  }
}

class CryptoOverviewModel {
  const CryptoOverviewModel({
    this.totalMarketCap = 0,
    this.marketCapChange24h = 0,
    this.btcDominance = 0,
    this.totalVolume = 0,
    this.activeCryptocurrencies = 0,
    this.fearGreedValue = 0,
    this.fearGreedLabel = '',
    this.trending = const [],
    this.stale = false,
    this.provider = '',
  });

  final double totalMarketCap;
  final double marketCapChange24h;
  final double btcDominance;
  final double totalVolume;
  final int activeCryptocurrencies;
  final int fearGreedValue;
  final String fearGreedLabel;
  final List<CryptoAssetModel> trending;
  final bool stale;
  final String provider;

  factory CryptoOverviewModel.fromJson(Map<String, dynamic> json) {
    final fear = _pick(json, 'fearGreed', 'fear_greed');
    final trendingRaw = json['trending'] as List<dynamic>? ?? [];
    return CryptoOverviewModel(
      totalMarketCap: _num(_pick(json, 'totalMarketCap', 'total_market_cap')),
      marketCapChange24h: _num(
        _pick(json, 'marketCapChange24h', 'market_cap_change_percentage_24h'),
      ),
      btcDominance: _num(_pick(json, 'btcDominance', 'btc_dominance')),
      totalVolume: _num(_pick(json, 'totalVolume', 'total_volume')),
      activeCryptocurrencies: _int(
        _pick(json, 'activeCryptocurrencies', 'active_cryptocurrencies'),
      ),
      fearGreedValue: fear is Map ? _int(fear['value']) : 0,
      fearGreedLabel: fear is Map ? (fear['classification'] as String? ?? '') : '',
      trending: trendingRaw
          .whereType<Map<String, dynamic>>()
          .map(CryptoAssetModel.fromJson)
          .toList(),
      stale: json['stale'] as bool? ?? false,
      provider: (json['provider'] as String?) ?? '',
    );
  }
}

class CryptoNewsResponse {
  const CryptoNewsResponse({
    this.results = const [],
    this.categories = const [],
  });

  final List<CryptoNewsModel> results;
  final List<String> categories;

  factory CryptoNewsResponse.fromJson(Map<String, dynamic> json) =>
      CryptoNewsResponse(
        results: (json['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CryptoNewsModel.fromJson)
            .toList(),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class CryptoNewsModel {
  const CryptoNewsModel({
    required this.id,
    required this.title,
    this.summary = '',
    this.imageUrl = '',
    this.source = '',
    required this.publishedAt,
    this.category = '',
    this.relatedCryptocurrencies = const [],
    this.externalUrl = '',
  });

  final String id;
  final String title;
  final String summary;
  final String imageUrl;
  final String source;
  final DateTime publishedAt;
  final String category;
  final List<String> relatedCryptocurrencies;
  final String externalUrl;

  factory CryptoNewsModel.fromJson(Map<String, dynamic> json) => CryptoNewsModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        title: (_pick(json, 'title', 'title') as String?) ?? '',
        summary: (_pick(json, 'summary', 'summary') as String?) ?? '',
        imageUrl: (_pick(json, 'imageUrl', 'image_url') as String?) ?? '',
        source: (_pick(json, 'source', 'source') as String?) ?? '',
        publishedAt: _date(_pick(json, 'publishedAt', 'published_at')),
        category: (_pick(json, 'category', 'category') as String?) ?? '',
        relatedCryptocurrencies: (_pick(json, 'relatedCryptocurrencies', 'related_cryptocurrencies')
                    as List<dynamic>? ??
                [])
            .map((e) => e.toString())
            .toList(),
        externalUrl: (_pick(json, 'externalUrl', 'external_url') as String?) ?? '',
      );
}

class CryptoWatchlistItemModel {
  const CryptoWatchlistItemModel({
    required this.id,
    required this.assetId,
    required this.symbol,
    required this.name,
    this.imageUrl = '',
    this.currentPrice = 0,
    this.change24hPct = 0,
    this.sparkline = const [],
    this.addedAt,
  });

  final String id;
  final String assetId;
  final String symbol;
  final String name;
  final String imageUrl;
  final double currentPrice;
  final double change24hPct;
  final List<double> sparkline;
  final DateTime? addedAt;

  bool get isPositive => change24hPct >= 0;

  CryptoAssetModel toAsset() => CryptoAssetModel(
        id: assetId,
        symbol: symbol,
        name: name,
        imageUrl: imageUrl,
        currentPrice: currentPrice,
        change24hPct: change24hPct,
        sparkline: sparkline,
      );

  factory CryptoWatchlistItemModel.fromJson(Map<String, dynamic> json) =>
      CryptoWatchlistItemModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        assetId: (_pick(json, 'assetId', 'asset_id') ?? '').toString(),
        symbol: ((_pick(json, 'symbol', 'symbol') as String?) ?? '').toUpperCase(),
        name: (_pick(json, 'name', 'name') as String?) ?? '',
        imageUrl: (_pick(json, 'imageUrl', 'image_url') as String?) ?? '',
        currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
        change24hPct: _num(
          _pick(json, 'change24hPct', 'price_change_percentage_24h'),
        ),
        sparkline: _sparkline(_pick(json, 'sparkline7d', 'sparkline_7d')),
        addedAt: _pick(json, 'addedAt', 'added_at') != null
            ? _date(_pick(json, 'addedAt', 'added_at'))
            : null,
      );
}

class CryptoHoldingModel {
  const CryptoHoldingModel({
    required this.assetId,
    required this.symbol,
    required this.name,
    this.imageUrl = '',
    this.quantity = 0,
    this.avgPrice = 0,
    this.currentPrice = 0,
    this.invested = 0,
    this.currentValue = 0,
    this.unrealizedPnl = 0,
    this.unrealizedPnlPercent = 0,
  });

  final String assetId;
  final String symbol;
  final String name;
  final String imageUrl;
  final double quantity;
  final double avgPrice;
  final double currentPrice;
  final double invested;
  final double currentValue;
  final double unrealizedPnl;
  final double unrealizedPnlPercent;

  bool get isPositive => unrealizedPnl >= 0;

  factory CryptoHoldingModel.fromJson(Map<String, dynamic> json) => CryptoHoldingModel(
        assetId: (_pick(json, 'assetId', 'asset_id') ?? '').toString(),
        symbol: ((_pick(json, 'symbol', 'symbol') as String?) ?? '').toUpperCase(),
        name: (_pick(json, 'name', 'name') as String?) ?? '',
        imageUrl: (_pick(json, 'imageUrl', 'image_url') as String?) ?? '',
        quantity: _num(_pick(json, 'quantity', 'quantity')),
        avgPrice: _num(_pick(json, 'avgPrice', 'avg_price')),
        currentPrice: _num(_pick(json, 'currentPrice', 'current_price')),
        invested: _num(_pick(json, 'invested', 'invested')),
        currentValue: _num(_pick(json, 'currentValue', 'current_value')),
        unrealizedPnl: _num(_pick(json, 'unrealizedPnl', 'unrealized_pnl')),
        unrealizedPnlPercent: _num(
          _pick(json, 'unrealizedPnlPercent', 'unrealized_pnl_percent'),
        ),
      );
}

class CryptoPortfolioModel {
  const CryptoPortfolioModel({
    this.environment = 'PAPER TRADING',
    this.walletBalance = 0,
    this.investedAmount = 0,
    this.currentValue = 0,
    this.totalPortfolioValue = 0,
    this.profitLoss = 0,
    this.profitLossPercent = 0,
    this.holdings = const [],
    this.allocation = const [],
  });

  final String environment;
  final double walletBalance;
  final double investedAmount;
  final double currentValue;
  final double totalPortfolioValue;
  final double profitLoss;
  final double profitLossPercent;
  final List<CryptoHoldingModel> holdings;
  final List<CryptoAllocationItem> allocation;

  bool get isPositive => profitLoss >= 0;

  factory CryptoPortfolioModel.fromJson(Map<String, dynamic> json) =>
      CryptoPortfolioModel(
        environment: (_pick(json, 'environment', 'environment') as String?) ??
            'PAPER TRADING',
        walletBalance: _num(_pick(json, 'walletBalance', 'wallet_balance')),
        investedAmount: _num(_pick(json, 'investedAmount', 'invested_amount')),
        currentValue: _num(_pick(json, 'currentValue', 'current_value')),
        totalPortfolioValue: _num(
          _pick(json, 'totalPortfolioValue', 'total_portfolio_value'),
        ),
        profitLoss: _num(_pick(json, 'profitLoss', 'profit_loss')),
        profitLossPercent: _num(
          _pick(json, 'profitLossPercent', 'profit_loss_percent'),
        ),
        holdings: (json['holdings'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CryptoHoldingModel.fromJson)
            .toList(),
        allocation: (json['allocation'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CryptoAllocationItem.fromJson)
            .toList(),
      );
}

class CryptoAllocationItem {
  const CryptoAllocationItem({
    required this.assetId,
    required this.symbol,
    required this.percent,
  });

  final String assetId;
  final String symbol;
  final double percent;

  factory CryptoAllocationItem.fromJson(Map<String, dynamic> json) =>
      CryptoAllocationItem(
        assetId: (_pick(json, 'assetId', 'asset_id') ?? '').toString(),
        symbol: ((_pick(json, 'symbol', 'symbol') as String?) ?? '').toUpperCase(),
        percent: _num(_pick(json, 'percent', 'percent')),
      );
}

class CryptoChartPoint {
  const CryptoChartPoint({required this.time, required this.value});

  final DateTime time;
  final double value;
}

class CryptoChartModel {
  const CryptoChartModel({
    required this.assetId,
    required this.period,
    this.prices = const [],
    this.volumes = const [],
  });

  final String assetId;
  final String period;
  final List<CryptoChartPoint> prices;
  final List<CryptoChartPoint> volumes;

  factory CryptoChartModel.fromJson(Map<String, dynamic> json) {
    List<CryptoChartPoint> parsePoints(dynamic raw) {
      if (raw is! List) return const [];
      final out = <CryptoChartPoint>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(CryptoChartPoint(
            time: DateTime.fromMillisecondsSinceEpoch(_int(item['t'])),
            value: _num(item['v']),
          ));
        } else if (item is List && item.length >= 2) {
          out.add(CryptoChartPoint(
            time: DateTime.fromMillisecondsSinceEpoch(_int(item[0])),
            value: _num(item[1]),
          ));
        }
      }
      return out;
    }

    return CryptoChartModel(
      assetId: (_pick(json, 'id', 'id') ?? '').toString(),
      period: (_pick(json, 'period', 'period') as String?) ?? '1D',
      prices: parsePoints(json['prices']),
      volumes: parsePoints(json['volumes']),
    );
  }
}

class CryptoTransactionModel {
  const CryptoTransactionModel({
    required this.id,
    this.assetId = '',
    this.symbol = '',
    this.txType = '',
    this.quantity = 0,
    this.price = 0,
    this.totalValue = 0,
    this.status = '',
    this.isPaper = true,
    required this.createdAt,
  });

  final String id;
  final String assetId;
  final String symbol;
  final String txType;
  final double quantity;
  final double price;
  final double totalValue;
  final String status;
  final bool isPaper;
  final DateTime createdAt;

  factory CryptoTransactionModel.fromJson(Map<String, dynamic> json) =>
      CryptoTransactionModel(
        id: (_pick(json, 'id', 'id') ?? '').toString(),
        assetId: (_pick(json, 'assetId', 'asset_id') ?? '').toString(),
        symbol: ((_pick(json, 'symbol', 'symbol') as String?) ?? '').toUpperCase(),
        txType: (_pick(json, 'txType', 'tx_type') as String?) ?? '',
        quantity: _num(_pick(json, 'quantity', 'quantity')),
        price: _num(_pick(json, 'price', 'price')),
        totalValue: _num(_pick(json, 'totalValue', 'total_value')),
        status: (_pick(json, 'status', 'status') as String?) ?? '',
        isPaper: _pick(json, 'isPaper', 'is_paper') as bool? ?? true,
        createdAt: _date(_pick(json, 'createdAt', 'created_at')),
      );
}

class CryptoWalletModel {
  const CryptoWalletModel({
    this.balance = 0,
    this.currency = 'INR',
    this.environment = 'PAPER TRADING',
  });

  final double balance;
  final String currency;
  final String environment;

  factory CryptoWalletModel.fromJson(Map<String, dynamic> json) => CryptoWalletModel(
        balance: _num(_pick(json, 'balance', 'balance')),
        currency: (_pick(json, 'currency', 'currency') as String?) ?? 'INR',
        environment: (_pick(json, 'environment', 'environment') as String?) ??
            'PAPER TRADING',
      );
}

class CryptoNotificationPreferenceModel {
  const CryptoNotificationPreferenceModel({
    this.priceAlerts = true,
    this.newsAlerts = true,
    this.volatilityAlerts = false,
    this.percentMoveThreshold = 5,
  });

  final bool priceAlerts;
  final bool newsAlerts;
  final bool volatilityAlerts;
  final double percentMoveThreshold;

  factory CryptoNotificationPreferenceModel.fromJson(Map<String, dynamic> json) =>
      CryptoNotificationPreferenceModel(
        priceAlerts: _pick(json, 'priceAlerts', 'price_alerts') as bool? ?? true,
        newsAlerts: _pick(json, 'newsAlerts', 'news_alerts') as bool? ?? true,
        volatilityAlerts:
            _pick(json, 'volatilityAlerts', 'volatility_alerts') as bool? ?? false,
        percentMoveThreshold: _num(
          _pick(json, 'percentMoveThreshold', 'percent_move_threshold'),
        ),
      );

  Map<String, dynamic> toJson() => {
        'price_alerts': priceAlerts,
        'news_alerts': newsAlerts,
        'volatility_alerts': volatilityAlerts,
        'percent_move_threshold': percentMoveThreshold,
      };
}

class CryptoScreenerResult {
  const CryptoScreenerResult({
    this.results = const [],
    this.page = 1,
    this.pageSize = 50,
  });

  final List<CryptoAssetModel> results;
  final int page;
  final int pageSize;

  factory CryptoScreenerResult.fromJson(Map<String, dynamic> json) =>
      CryptoScreenerResult(
        results: (json['results'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CryptoAssetModel.fromJson)
            .toList(),
        page: _int(json['page']),
        pageSize: _int(_pick(json, 'pageSize', 'page_size')),
      );
}

List<CryptoAssetModel> parseCryptoAssetList(dynamic data) {
  if (data is! List) return const [];
  return data
      .whereType<Map<String, dynamic>>()
      .map(CryptoAssetModel.fromJson)
      .toList();
}

@visibleForTesting
double cryptoNum(dynamic v) => _num(v);
