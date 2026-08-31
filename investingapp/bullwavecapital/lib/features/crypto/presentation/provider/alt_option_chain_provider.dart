import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/stock_model.dart';
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
    final id = underlyingId.trim().toLowerCase();
    final state = _state(kind, id);
    state.loading = true;
    state.error = null;
    notifyListeners();

    try {
      final chain = kind == AltMarketKind.crypto
          ? await _api.getCryptoOptionChain(id, expiry: expiry)
          : await _api.getForexOptionChain(id, expiry: expiry);
      if (chain.contracts.isEmpty) {
        state.error = 'No option contracts for $id';
      } else {
        state.contracts = chain.contracts;
        state.underlying = chain.underlyingValue;
        state.expiries = chain.expiryDates;
        state.selectedExpiry = chain.selectedExpiry;
        state.symbol = chain.symbol;
        state.error = null;
      }
    } on ApiException catch (e) {
      if (state.contracts.isEmpty) state.error = e.message;
    } catch (_) {
      if (state.contracts.isEmpty) {
        state.error = 'Could not load options. Please try again.';
      }
    }

    state.loading = false;
    notifyListeners();
  }
}
