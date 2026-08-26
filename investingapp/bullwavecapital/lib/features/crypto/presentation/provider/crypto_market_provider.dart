import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../core/api/token_storage.dart';
import '../../../../models/crypto_models.dart';

/// Local cache for active market selection (offline UX).
class CryptoMarketPreferenceCache {
  CryptoMarketPreferenceCache._();

  static const _activeMarketKey = 'crypto_active_market_local';
  static const _completedKey = 'crypto_market_completed_local';

  static Future<String?> readActiveMarket() async {
    final cached = await TokenStorage.getActiveMarket();
    if (cached != null && cached.isNotEmpty) return cached;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeMarketKey);
  }

  static Future<void> writeActiveMarket(String market) async {
    await TokenStorage.setActiveMarket(market);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeMarketKey, market);
  }

  static Future<bool> readCompleted() async {
    if (await TokenStorage.hasMarketPreferenceCompleted()) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_completedKey) ?? false;
  }

  static Future<void> writeCompleted(bool value) async {
    await TokenStorage.setMarketPreferenceCompleted(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey, value);
  }
}

class CryptoMarketProvider extends ChangeNotifier {
  CryptoMarketProvider();

  final _api = BullwaveApi.instance;

  UserMarketPreferenceModel? _preference;
  CryptoOverviewModel? _overview;
  List<CryptoAssetModel> _assets = [];
  List<CryptoWatchlistItemModel> _watchlist = [];
  List<CryptoNewsModel> _news = [];
  List<String> _newsCategories = [];
  CryptoPortfolioModel? _portfolio;
  List<CryptoAssetModel> _searchResults = [];
  CryptoScreenerResult? _screener;
  final Map<String, List<CryptoAssetModel>> _moversCache = {};

  String _activeMarket = 'indian';
  String _searchQuery = '';
  String? _error;
  bool _isLoading = false;
  bool _isStale = false;
  bool _preferenceLoaded = false;
  bool _initialized = false;

  String get activeMarket => _activeMarket;
  bool get isCryptoActive => _activeMarket == 'crypto';
  bool get isIndianActive => _activeMarket == 'indian';
  UserMarketPreferenceModel? get preference => _preference;
  CryptoOverviewModel? get overview => _overview;
  List<CryptoAssetModel> get assets => _assets;
  List<CryptoWatchlistItemModel> get watchlist => _watchlist;
  List<CryptoNewsModel> get news => _news;
  List<String> get newsCategories => _newsCategories;
  CryptoPortfolioModel? get portfolio => _portfolio;
  List<CryptoAssetModel> get searchResults => _searchResults;
  CryptoScreenerResult? get screener => _screener;
  String get searchQuery => _searchQuery;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isStale => _isStale;
  bool get preferenceLoaded => _preferenceLoaded;
  bool get hasCompletedSelection =>
      _preference?.hasCompletedSelection ??
      false;

  bool isInWatchlist(String assetId) =>
      _watchlist.any((w) => w.assetId == assetId);

  CryptoWatchlistItemModel? watchlistItemFor(String assetId) {
    try {
      return _watchlist.firstWhere((w) => w.assetId == assetId);
    } catch (_) {
      return null;
    }
  }

  List<CryptoAssetModel> movers(String type) => _moversCache[type] ?? const [];

  Future<void> ensurePreferenceLoaded() async {
    if (_preferenceLoaded) return;
    await loadPreference();
  }

  Future<void> loadPreference() async {
    try {
      _preference = await _api.getMarketPreference();
      _activeMarket = _preference!.activeMarket;
      if (_preference!.hasCompletedSelection) {
        await CryptoMarketPreferenceCache.writeCompleted(true);
      }
      await CryptoMarketPreferenceCache.writeActiveMarket(_activeMarket);
    } on ApiException catch (e) {
      final cached = await CryptoMarketPreferenceCache.readActiveMarket();
      _activeMarket = cached ?? 'indian';
      _error = e.message;
    } catch (_) {
      final cached = await CryptoMarketPreferenceCache.readActiveMarket();
      _activeMarket = cached ?? 'indian';
    } finally {
      _preferenceLoaded = true;
      notifyListeners();
    }
  }

  /// One market at a time — exclusive indian XOR crypto.
  Future<bool> savePreference({
    required bool indianMarketEnabled,
    required bool cryptoMarketEnabled,
    String? activeMarket,
  }) async {
    // Enforce exclusive selection on the client.
    var indian = indianMarketEnabled;
    var crypto = cryptoMarketEnabled;
    var active = (activeMarket ?? _activeMarket).trim().toLowerCase();
    if (indian && crypto) {
      if (active == 'crypto') {
        indian = false;
        crypto = true;
      } else {
        indian = true;
        crypto = false;
        active = 'indian';
      }
    } else if (crypto && !indian) {
      active = 'crypto';
    } else if (indian && !crypto) {
      active = 'indian';
    } else {
      _error = 'Select a market to continue.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _preference = await _api.saveMarketPreference(
        indianMarketEnabled: indian,
        cryptoMarketEnabled: crypto,
        activeMarket: active,
      );
      _activeMarket = _preference!.activeMarket;
      await CryptoMarketPreferenceCache.writeCompleted(true);
      await CryptoMarketPreferenceCache.writeActiveMarket(_activeMarket);
      if (_activeMarket == 'crypto') {
        unawaited(ensureLoaded());
      }
      return true;
    } on ApiException catch (e) {
      // Prefer local preference so UI still works before AWS crypto deploy.
      if (e.statusCode == 404 || e.statusCode == 502 || e.statusCode == 503) {
        _preference = UserMarketPreferenceModel(
          indianMarketEnabled: indian,
          cryptoMarketEnabled: crypto,
          activeMarket: active,
          hasCompletedSelection: true,
        );
        _activeMarket = active;
        await CryptoMarketPreferenceCache.writeCompleted(true);
        await CryptoMarketPreferenceCache.writeActiveMarket(_activeMarket);
        _error = null;
        if (_activeMarket == 'crypto') {
          unawaited(ensureLoaded());
        }
        return true;
      }
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchMarket(String market) async {
    final next = market.trim().toLowerCase();
    if (next != 'indian' && next != 'crypto') return;
    if (next == _activeMarket &&
        ((_preference?.indianMarketEnabled ?? false) == (next == 'indian')) &&
        ((_preference?.cryptoMarketEnabled ?? false) == (next == 'crypto'))) {
      return;
    }

    // Switching markets is exclusive: enable only the selected one.
    final ok = await savePreference(
      indianMarketEnabled: next == 'indian',
      cryptoMarketEnabled: next == 'crypto',
      activeMarket: next,
    );
    if (!ok) return;
    if (next == 'crypto') {
      await ensureLoaded();
    }
  }

  Future<void> ensureLoaded() async {
    if (_initialized && _assets.isNotEmpty) return;
    await refreshAll();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    Object? overviewErr;
    Object? assetsErr;
    await Future.wait([
      _tryLoad(_loadOverview, onError: (e) => overviewErr = e),
      _tryLoad(_loadAssets, onError: (e) => assetsErr = e),
      _tryLoad(_loadWatchlist),
      _tryLoad(_loadPortfolio),
    ]);

    _initialized = _overview != null || _assets.isNotEmpty;
    _isStale = _overview?.stale ?? false;
    if (_overview == null && _assets.isEmpty) {
      _error = _marketError(overviewErr ?? assetsErr);
    } else {
      _error = null;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _tryLoad(
    Future<void> Function() fn, {
    void Function(Object error)? onError,
  }) async {
    try {
      await fn();
    } catch (e) {
      onError?.call(e);
    }
  }

  String _marketError(Object? error) {
    if (error is ApiException) {
      final message = error.message.trim();
      if (message.isNotEmpty) return message;
    }
    return 'Market data is temporarily unavailable. Please try again.';
  }

  Future<void> refreshOverview() async {
    try {
      await _loadOverview();
      _isStale = _overview?.stale ?? false;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    }
    notifyListeners();
  }

  Future<void> _loadOverview() async {
    _overview = await _api.getCryptoOverview();
  }

  Future<void> _loadAssets() async {
    _assets = await _api.getCryptoAssets(top: true, pageSize: 25);
  }

  Future<void> _loadWatchlist() async {
    _watchlist = await _api.getCryptoWatchlist();
  }

  Future<void> _loadPortfolio() async {
    _portfolio = await _api.getCryptoPortfolio();
  }

  Future<void> refreshPortfolio() async {
    try {
      await _loadPortfolio();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    }
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query.trim();
    if (_searchQuery.isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      _searchResults = await _api.searchCrypto(_searchQuery);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
      _searchResults = [];
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
      _searchResults = [];
    }
    notifyListeners();
  }

  Future<void> loadScreener({
    String sort = 'market_cap_desc',
    double? minChange24h,
    double? maxChange24h,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      _screener = await _api.getCryptoScreener(
        sort: sort,
        minChange24h: minChange24h,
        maxChange24h: maxChange24h,
      );
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMovers(String type) async {
    try {
      _moversCache[type] = await _api.getCryptoMovers(type: type);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    }
    notifyListeners();
  }

  Future<void> loadNews({String? category, bool refresh = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.getCryptoNews(category: category, refresh: refresh);
      _news = response.results;
      _newsCategories = response.categories;
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleWatchlist(String assetId) async {
    final existing = watchlistItemFor(assetId);
    try {
      if (existing != null) {
        await _api.removeCryptoWatchlist(existing.id);
        _watchlist.removeWhere((w) => w.id == existing.id);
      } else {
        final item = await _api.addCryptoWatchlist(assetId);
        _watchlist = [..._watchlist, item];
      }
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    }
    notifyListeners();
  }

  Future<Map<String, dynamic>?> placePaperOrder({
    required String assetId,
    required String side,
    required double quantity,
  }) async {
    try {
      final result = await _api.placeCryptoPaperOrder(
        assetId: assetId,
        side: side,
        quantity: quantity,
      );
      await refreshPortfolio();
      _error = null;
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
      notifyListeners();
      return null;
    }
  }
}
