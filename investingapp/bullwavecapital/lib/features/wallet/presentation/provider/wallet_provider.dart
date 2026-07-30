import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/api/bullwave_api.dart';
import '../../../../models/wallet_model.dart';
import '../../../kyc/data/payment_repository.dart';

class WalletProvider extends ChangeNotifier {
  final _api = BullwaveApi.instance;
  final _payments = PaymentRepository();

  bool _isLoading = true;
  String? error;
  WalletModel _wallet = const WalletModel(
    balance: 0,
    bankName: '',
    accountNumber: '',
    ifsc: '',
  );
  List<WalletTransaction> _transactions = [];
  double _practiceBalance = 100000;
  double _practiceInitialBalance = 100000;
  double _practiceRefillThreshold = 10000;
  List<Map<String, dynamic>> _practiceTransactions = [];

  bool get isLoading => _isLoading;
  String? get lastError => error;
  WalletModel get wallet => _wallet;
  List<WalletTransaction> get transactions => _transactions;
  double get practiceBalance => _practiceBalance;
  double get practiceInitialBalance => _practiceInitialBalance;
  double get practiceRefillThreshold => _practiceRefillThreshold;
  List<Map<String, dynamic>> get practiceTransactions =>
      List.unmodifiable(_practiceTransactions);

  WalletProvider() {
    loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _api.getWallet(),
        _api.getWalletTransactions(),
        _api.getPracticeWallet(),
      ]);
      _wallet = results[0] as WalletModel;
      _transactions = results[1] as List<WalletTransaction>;
      final practice = results[2] as Map<String, dynamic>;
      _practiceBalance = (practice['balance'] as num?)?.toDouble() ?? 100000;
      _practiceInitialBalance =
          (practice['initialBalance'] as num?)?.toDouble() ?? 100000;
      _practiceRefillThreshold =
          (practice['refillThreshold'] as num?)?.toDouble() ?? 10000;
      _practiceTransactions = (practice['transactions'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    } catch (e) {
      error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Cashfree Payouts withdrawal via `/withdraw/` (same as KYC withdraw screen).
  Future<bool> withdraw(double amount) async {
    error = null;
    try {
      await _payments.withdraw(amount);
      await loadData();
      return true;
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }

  Future<bool> deposit(double amount) async {
    error = null;
    try {
      final session = await _payments.createPayment(amount);
      if (session.devMode && session.success) {
        await loadData();
        return true;
      }
      error = 'Use the Add Money screen for Cashfree checkout.';
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
    return false;
  }
}
