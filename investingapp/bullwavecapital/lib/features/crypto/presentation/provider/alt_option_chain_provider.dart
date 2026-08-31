import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/stock_model.dart';
import '../../data/synthetic_option_chain.dart';
import '../widgets/alt_market_shortcuts.dart';

class _AltOptionState {
  List<OptionContractModel> contracts = [];
  double underlying = 0;
  List<String> expiries = [];
  String selectedExpiry = '';
  String symbol = '';
  bool loading = false;
  String? error;
}

class AltOptionChainProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;
  final Map<String, _AltOptionState> _chains = {};

  String _key(AltMarketKind kind, String id) => '${kind.name}:${id.toLowerCase()}';

  _AltOptionState _state(AltMarketKind kind, String id) =>
      _chains.putIfAbsent(_key(kind, id), () => _AltOptionState());

  List<OptionContractModel> contracts(AltMarketKind kind, String id) =>
      _state(kind, id).contracts;
  double spot(AltMarketKind kind, String id) => _state(kind, id).underlying;
  List<String> expiries(AltMarketKind kind, String id) =>
      _state(kind, id).expiries;
  String selectedExpiry(AltMarketKind kind, String id) =>
      _state(kind, id).selectedExpiry;
  String symbol(AltMarketKind kind, String id) => _state(kind, id).symbol;
  bool isLoading(AltMarketKind kind, String id) => _state(kind, id).loading;
  String? error(AltMarketKind kind, String id) => _state(kind, id).error;

  Future<void> load(
    AltMarketKind kind,
    String underlyingId, {
    String? expiry,
  }) async {
    final id = kind == AltMarketKind.crypto
        ? canonicalCryptoId(underlyingId)
        : canonicalForexId(underlyingId);
    final state = _state(kind, id);
    state.loading = true;
    state.error = null;
    notifyListeners();

    DateTime? selected;
    if (expiry != null && expiry.length >= 10) {
      selected = DateTime.tryParse(expiry.substring(0, 10));
    }

    try {
      final chain = kind == AltMarketKind.crypto
          ? await _api.getCryptoOptionChain(id, expiry: expiry)
          : await _api.getForexOptionChain(id, expiry: expiry);
      if (chain.contracts.isNotEmpty) {
        _apply(state, chain);
        state.loading = false;
        notifyListeners();
        return;
      }
    } on ApiException {
      // Live options URL is not on this server yet — build from spot.
    } catch (_) {}

    try {
      final liveSpot = await _liveSpot(kind, id);
      final chain = kind == AltMarketKind.crypto
          ? buildCryptoFallbackChain(id, spot: liveSpot, expiry: selected)
          : buildForexFallbackChain(id, spot: liveSpot, expiry: selected);
      _apply(state, chain);
    } catch (_) {
      final chain = kind == AltMarketKind.crypto
          ? buildCryptoFallbackChain(id, expiry: selected)
          : buildForexFallbackChain(id, expiry: selected);
      _apply(state, chain);
    }

    if (state.contracts.isEmpty) {
      state.error = 'Could not load options. Please try again.';
    }

    state.loading = false;
    notifyListeners();
  }

  Future<double?> _liveSpot(AltMarketKind kind, String id) async {
    try {
      if (kind == AltMarketKind.crypto) {
        final asset = await _api.getCryptoAsset(id);
        if (asset.currentPrice > 0) return asset.currentPrice;
      } else {
        final pair = await _api.getForexPair(id);
        if (pair.currentPrice > 0) return pair.currentPrice;
      }
    } catch (_) {}
    return null;
  }

  void _apply(_AltOptionState state, OptionChainResponse chain) {
    state.contracts = chain.contracts;
    state.underlying = chain.underlyingValue;
    state.expiries = chain.expiryDates;
    state.selectedExpiry = chain.selectedExpiry;
    state.symbol = chain.symbol;
    state.error = null;
  }
}
