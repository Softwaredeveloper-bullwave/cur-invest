import '../constants/routes.dart';

/// Phase 1 Play Store — market learning + paper trading simulator (ON by default).
///
/// Phase 2 real money: `--dart-define=PAPER_ONLY=false`
class PaperOnlyMode {
  PaperOnlyMode._();

  static const enabled = bool.fromEnvironment('PAPER_ONLY', defaultValue: true);

  static const disclaimer =
      'Simulated trading only. No real money. Not a SEBI-registered broker.';

  static const shortDisclaimer = 'Paper trading · Virtual funds only';

  static bool isBlockedRoute(String path) {
    if (!enabled) return false;
    if (_blockedExact.contains(path)) return true;
    if (path.startsWith('${AppRoutes.featuredPlan}/')) return true;
    if (path.startsWith(AppRoutes.goalDetail)) return true;
    return false;
  }

  static String? redirectFor(String path) {
    if (!isBlockedRoute(path)) return null;
    return AppRoutes.home;
  }

  /// Real-money only — Phase 1 still requires PAN / Aadhaar / bank KYC.
  static const _blockedExact = {
    AppRoutes.deposit,
    AppRoutes.depositSuccess,
    AppRoutes.withdraw,
    AppRoutes.featuredPlansList,
    AppRoutes.goalPlans,
    AppRoutes.createGoal,
    AppRoutes.copyTrading,
    AppRoutes.investmentDetails,
    AppRoutes.transactions,
    AppRoutes.fnoVerification,
  };
}
