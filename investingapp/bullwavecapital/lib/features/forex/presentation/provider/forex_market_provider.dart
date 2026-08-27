import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/forex_models.dart';

class ForexMarketProvider extends ChangeNotifier {
  ForexMarketProvider();

  final _api = BullwaveApi.instance;

  ForexOverviewModel? _overview;
  List<ForexPairModel> _pairs = [];
  List<ForexWatchlistItemModel> _watchlist = [];
  List<ForexNewsModel> _news = [];
  List<String> _newsCategories = [];
  ForexPortfolioModel? _portfolio;
  List<ForexPairModel> _searchResults = [];
  final Map<String, List<ForexPairModel>> _moversCache = {};
  String _searchQuery = '';
  String? _error;
  bool _isLoading = false;
  bool _initialized = false;

  ForexOverviewModel? get overview => _overview;
  List<ForexPairModel> get pairs => _pairs;
  List<ForexWatchlistItemModel> get watchlist => _watchlist;
  List<ForexNewsModel> get news => _news;
  List<String> get newsCategories => _newsCategories;
  ForexPortfolioModel? get portfolio => _portfolio;
  List<ForexPairModel> get searchResults => _searchResults;
  String get searchQuery => _searchQuery;
  String? get error => _error;
  bool get isLoading => _isLoading;

  bool isInWatchlist(String pairId) => _watchlist.any((w) => w.pairId == pairId);

  ForexWatchlistItemModel? watchlistItemFor(String pairId) {
    try {
      return _watchlist.firstWhere((w) => w.pairId == pairId);
    } catch (_) {
      return null;
    }
  }

  List<ForexPairModel> movers(String type) => _moversCache[type] ?? const [];

  Future<void> ensureLoaded() async {
    if (_initialized && _pairs.isNotEmpty) return;
    await refreshAll();
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    Object? overviewErr;
    Object? pairsErr;
    await Future.wait([
      _try(() async {
        _overview = await _api.getForexOverview();
      }, onError: (e) => overviewErr = e),
      _try(() async {
        _pairs = await _api.getForexPairs();
      }, onError: (e) => pairsErr = e),
      _try(() async {
        _watchlist = await _api.getForexWatchlist();
      }),
      _try(() async {
        _portfolio = await _api.getForexPortfolio();
      }),
    ]);
    _initialized = _overview != null || _pairs.isNotEmpty;
    if (_overview == null && _pairs.isEmpty) {
      _error = _msg(overviewErr ?? pairsErr);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> search(String query) async {
    _searchQuery = query;
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }
    try {
      _searchResults = await _api.searchForex(query.trim());
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Market data is temporarily unavailable. Please try again.';
    }
    notifyListeners();
  }

  Future<void> loadNews({bool refresh = false}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.getForexNews(refresh: refresh);
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

  Future<void> loadMovers(String type) async {
    try {
      _moversCache[type] = await _api.getForexMovers(type: type);
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  Future<void> loadPortfolio() async {
    try {
      _portfolio = await _api.getForexPortfolio();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleWatchlist(String pairId) async {
    final existing = watchlistItemFor(pairId);
    try {
      if (existing != null) {
        await _api.removeForexWatchlist(existing.id);
        _watchlist.removeWhere((w) => w.id == existing.id);
      } else {
        final item = await _api.addForexWatchlist(pairId);
        _watchlist = [..._watchlist, item];
      }
      _error = null;
    } on ApiException catch (e) {
      _error = e.message;
    }
    notifyListeners();
  }

  Future<void> _try(Future<void> Function() fn, {void Function(Object e)? onError}) async {
    try {
      await fn();
    } catch (e) {
      onError?.call(e);
    }
  }

  String _msg(Object? err) {
    if (err is ApiException) return err.message;
    return 'Market data is temporarily unavailable. Please try again.';
  }
}
