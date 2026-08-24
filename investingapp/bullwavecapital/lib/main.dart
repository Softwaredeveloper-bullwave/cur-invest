import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/api/bullwave_api.dart';
import 'core/api/dev_auth_service.dart';
import 'core/api/token_storage.dart';
import 'core/charts/tradingview_config.dart';
import 'core/config/dev_config.dart';
import 'core/constants/brand.dart';
import 'core/routes/app_router.dart';
import 'core/services/app_error_reporter.dart';
import 'core/security/app_lock_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/premium_background.dart';
import 'features/authentication/presentation/widgets/splash_animation.dart';
import 'features/authentication/presentation/provider/auth_provider.dart';
import 'features/kyc/presentation/provider/kyc_flow_provider.dart';
import 'features/home/presentation/provider/home_provider.dart';
import 'features/investment/presentation/provider/investment_provider.dart';
import 'features/portfolio/presentation/provider/portfolio_provider.dart';
import 'features/wallet/presentation/provider/wallet_provider.dart';
import 'features/transactions/presentation/provider/transaction_provider.dart';
import 'features/notifications/presentation/provider/notification_provider.dart';
import 'features/kyc/presentation/provider/bank_verification_provider.dart';
import 'features/profile/presentation/provider/app_provider.dart';
import 'features/profile/presentation/provider/referral_support_provider.dart';
import 'features/stocks/presentation/provider/commodity_provider.dart';
import 'features/stocks/presentation/provider/notes_provider.dart';
import 'features/education/presentation/provider/education_provider.dart';
import 'features/stocks/presentation/provider/stock_market_provider.dart';
import 'features/stocks/presentation/provider/stock_portfolio_provider.dart';
import 'features/stocks/presentation/provider/option_trading_provider.dart';
import 'features/stocks/presentation/provider/stock_features_provider.dart';
import 'features/stocks/presentation/provider/copy_trading_provider.dart';
import 'features/stocks/presentation/provider/paper_competition_provider.dart';
import 'features/stocks/presentation/provider/institutional_flow_provider.dart';
import 'features/fno/presentation/provider/fno_flow_provider.dart';
import 'features/goals/presentation/provider/goal_plan_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppErrorReporter.instance.report(
        details.exception,
        details.stack,
        location: details.library ?? 'flutter_framework',
        severity: 'critical',
      ),
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(
      AppErrorReporter.instance.report(
        error,
        stack,
        location: 'platform_dispatcher',
        severity: 'critical',
      ),
    );
    return true;
  };
  await TokenStorage.init();
  await AppErrorReporter.instance.initialize();
  await BullwaveApi.instance.init();
  if (DevConfig.enabled) {
    await DevAuthService.ensureSession(BullwaveApi.instance);
  }
  try {
    final tvConfig = await BullwaveApi.instance.getTradingViewConfig();
    TradingViewConfig.applyRemoteConfig(tvConfig);
  } catch (_) {
    // Backend offline — fall back to --dart-define values.
  }
  final appProvider = await AppProvider.create();
  runApp(BullWaveApp(appProvider: appProvider));
}

class BullWaveApp extends StatefulWidget {
  const BullWaveApp({super.key, required this.appProvider});

  final AppProvider appProvider;

  @override
  State<BullWaveApp> createState() => _BullWaveAppState();
}

class _BullWaveAppState extends State<BullWaveApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider = AuthProvider();
  late final AppLockProvider _appLockProvider = AppLockProvider();
  late final KycFlowProvider _kycFlowProvider = KycFlowProvider()
    ..onIdentityUpdated = () async {
      await _authProvider.refreshProfile();
    };
  late final _router = AppRouter.create(
    _authProvider,
    _kycFlowProvider,
    widget.appProvider,
    _appLockProvider,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock only when the app is fully backgrounded. Do not lock on inactive —
    // that state also fires when the biometric sheet opens and would cancel auth.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _appLockProvider.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.appProvider),
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _appLockProvider),
        ChangeNotifierProvider.value(value: _kycFlowProvider),
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => InvestmentProvider()),
        ChangeNotifierProvider(create: (_) => PortfolioProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => BankVerificationProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
        ChangeNotifierProvider(create: (_) => ReferralProvider()),
        ChangeNotifierProvider(create: (_) => StockMarketProvider()),
        ChangeNotifierProvider(create: (_) => CommodityProvider()),
        ChangeNotifierProvider(create: (_) => StockPortfolioProvider()),
        ChangeNotifierProvider(create: (_) => StockFeaturesProvider()),
        ChangeNotifierProvider(create: (_) => CopyTradingProvider()),
        ChangeNotifierProvider(create: (_) => PaperCompetitionProvider()),
        ChangeNotifierProvider(create: (_) => InstitutionalFlowProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => EducationProvider()),
        ChangeNotifierProvider(create: (_) => OptionTradingProvider()),
        ChangeNotifierProvider(create: (_) => FnoFlowProvider()),
        ChangeNotifierProvider(create: (_) => GoalPlanProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp.router(
            title: AppBrand.fullName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            routerConfig: _router,
            builder: (context, child) {
              if (child == null) {
                return const PremiumAppBackdrop(child: SplashAnimation());
              }
              return PremiumAppBackdrop(child: child);
            },
          );
        },
      ),
    );
  }
}
