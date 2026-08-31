import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/option_trade_model.dart';

class OptionTradingProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;

  List<OptionHoldingModel> _holdings = [];
  bool _loadingHoldings = false;
  String? _tradeError;

  List<OptionHoldingModel> get holdings => List.unmodifiable(_holdings);
  bool get loadingHoldings => _loadingHoldings;
  String? get tradeError => _tradeError;

  List<OptionHoldingModel> holdingsFor(String assetClass) =>
      _holdings.where((h) => h.assetClass == assetClass).toList();

  Future<void> loadHoldings({String? assetClass}) async {
    _loadingHoldings = true;
    notifyListeners();
    try {
      final list = await _api.getOptionHoldings(assetClass: assetClass);
      if (assetClass == null || assetClass.isEmpty) {
        _holdings = list;
      } else {
        _holdings = [
          ..._holdings.where((h) => h.assetClass != assetClass),
          ...list,
        ];
      }
      _tradeError = null;
    } catch (_) {
      // Keep last known book so home trades do not vanish on a blip.
    }
    _loadingHoldings = false;
    notifyListeners();
  }

  int holdingLots({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String assetClass,
  }) {
    final expiryKey = expiry.toIso8601String().substring(0, 10);
    for (final h in _holdings) {
      if (h.underlying == underlying.toUpperCase() &&
          h.assetClass == assetClass &&
          h.optionType == optionType.toUpperCase() &&
          (h.strike - strike).abs() < 0.0001 &&
          h.expiry.toIso8601String().substring(0, 10) == expiryKey) {
        return h.quantity;
      }
    }
    return 0;
  }

  Future<OptionTradeModel?> placeOrder({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String side,
    required int quantity,
    required double premium,
    required String assetClass,
  }) async {
    _tradeError = null;
    notifyListeners();
    try {
      final trade = await _api.placeOptionOrder(
        underlying: underlying,
        strike: strike,
        optionType: optionType,
        expiry: expiry,
        side: side,
        quantity: quantity,
        premium: premium,
        assetClass: assetClass,
      );
      await loadHoldings(assetClass: assetClass);
      return trade;
    } on ApiException catch (e) {
      _tradeError = e.message;
    } catch (_) {
      _tradeError = 'Could not place option order.';
    }
    notifyListeners();
    return null;
  }

  Future<Map<String, dynamic>?> placeScalperOrder({
    required String underlying,
    required double strike,
    required String optionType,
    required DateTime expiry,
    required String side,
    required int quantity,
    required double premium,
    required String assetClass,
    required String orderType,
    double? limitPrice,
    double? stopLoss,
    double? targetPrice,
    double? trailingStopPercent,
  }) async {
    _tradeError = null;
    try {
      final order = await _api.placeScalperOrder(
        instrumentType: 'option',
        orderType: orderType,
        side: side,
        quantity: quantity,
        underlying: underlying,
        strike: strike,
        optionType: optionType,
        expiry: expiry,
        assetClass: assetClass,
        requestedPrice: premium,
        limitPrice: limitPrice,
        stopLoss: stopLoss,
        targetPrice: targetPrice,
        trailingStopPercent: trailingStopPercent,
      );
      await loadHoldings(assetClass: assetClass);
      return order;
    } on ApiException catch (e) {
      _tradeError = e.message;
    } catch (_) {
      _tradeError = 'Could not place option scalper order.';
    }
    notifyListeners();
    return null;
  }
}
