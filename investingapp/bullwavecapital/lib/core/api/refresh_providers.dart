import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/home/presentation/provider/home_provider.dart';
import '../../features/kyc/presentation/provider/kyc_flow_provider.dart';
import '../../features/notifications/presentation/provider/notification_provider.dart';
import '../../features/portfolio/presentation/provider/portfolio_provider.dart';
import '../../features/profile/presentation/provider/referral_support_provider.dart';
import '../../features/stocks/presentation/provider/stock_features_provider.dart';
import '../../features/stocks/presentation/provider/stock_market_provider.dart';
import '../../features/stocks/presentation/provider/stock_portfolio_provider.dart';
import '../../features/transactions/presentation/provider/transaction_provider.dart';
import '../../features/wallet/presentation/provider/wallet_provider.dart';

/// Reload authenticated data after login.
Future<void> refreshAllProviders(BuildContext context) async {
  final tasks = <Future<void>>[
    _safe('KycFlowProvider', () => context.read<KycFlowProvider>().loadStatus()),
    _safe('HomeProvider', () => context.read<HomeProvider>().refresh()),
    _safe('WalletProvider', () => context.read<WalletProvider>().loadData()),
    _safe('TransactionProvider', () => context.read<TransactionProvider>().loadData()),
    _safe('NotificationProvider', () => context.read<NotificationProvider>().loadData()),
    _safe('SupportProvider', () => context.read<SupportProvider>().loadData()),
    _safe('ReferralProvider', () => context.read<ReferralProvider>().loadData()),
    _safe('PortfolioProvider', () => context.read<PortfolioProvider>().loadData()),
    _safe('StockMarketProvider', () => context.read<StockMarketProvider>().ensureLoaded()),
    _safe(
      'StockPortfolioProvider',
      () => context.read<StockPortfolioProvider>().loadPortfolio(
        refreshQuotes: false,
      ),
    ),
    _safe('StockFeaturesProvider', () => context.read<StockFeaturesProvider>().loadAll()),
  ];

  try {
    await Future.wait(tasks).timeout(const Duration(seconds: 20));
  } on TimeoutException catch (e) {
    debugPrint('refreshAllProviders timeout: $e');
  }
}

Future<void> _safe(String label, Future<void> Function() task) async {
  try {
    await task().timeout(const Duration(seconds: 12));
  } catch (e) {
    debugPrint('refreshAllProviders failed ($label): $e');
  }
}
