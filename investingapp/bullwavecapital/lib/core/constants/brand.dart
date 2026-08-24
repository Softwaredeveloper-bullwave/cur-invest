import '../config/paper_only_mode.dart';

/// App-wide display name for Capital BullWave (CBW).
class AppBrand {
  AppBrand._();

  static const String name = 'Capital BullWave';
  static const String acronym = 'CBW';
  static const String fullName = 'Capital BullWave (CBW)';

  static String get tagline => PaperOnlyMode.enabled
      ? 'Market learning & paper trading simulator.\nPractice with virtual funds — no real money.'
      : 'Invest smarter. Trade faster.\nGrow wealth with confidence.';

  static String get aboutDescription => PaperOnlyMode.enabled
      ? 'Capital BullWave is a market learning and paper trading app for Indian markets. '
            'Explore live charts, watchlists, educational content, and practice trades with virtual money. '
            'This is not investment advice. Not a SEBI-registered broker. No real-money deposits.'
      : 'Capital BullWave is an Indian investment platform for paper trading, '
            'goal-based plans, research tools, wallet funding, and KYC-verified investing.';

  /// Play Store short category label (internal / about screen).
  static String get storeCategoryLabel => PaperOnlyMode.enabled
      ? 'Education · Paper Trading Simulator'
      : 'Finance · Investment Platform';
}
