import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../provider/crypto_market_provider.dart';

/// Post-KYC market pick — one market at a time.
class MarketInterestScreen extends StatefulWidget {
  const MarketInterestScreen({super.key});

  @override
  State<MarketInterestScreen> createState() => _MarketInterestScreenState();
}

class _MarketInterestScreenState extends State<MarketInterestScreen> {
  /// `indian` | `crypto`
  String _selected = 'indian';
  bool _saving = false;

  Future<void> _continue() async {
    setState(() => _saving = true);
    final provider = context.read<CryptoMarketProvider>();
    final ok = await provider.savePreference(
      indianMarketEnabled: _selected == 'indian',
      cryptoMarketEnabled: _selected == 'crypto',
      activeMarket: _selected,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      // Home shell shows crypto dashboard when activeMarket == crypto.
      context.go(AppRoutes.home);
    } else {
      AppSnackbar.error(
        context,
        provider.error ??
            'Market data is temporarily unavailable. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Choose your market',
                style: context.typeHeading.copyWith(fontSize: 28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select one market. You can change this anytime in Settings.',
                style: context.typeSecondary(15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _MarketCard(
                title: '🇮🇳 Indian Market',
                subtitle: 'Stocks • NSE • BSE • Market News • Trading',
                icon: Icons.candlestick_chart_outlined,
                selected: _selected == 'indian',
                accent: AppColors.brandPrimary,
                onTap: () => setState(() => _selected = 'indian'),
              ),
              const SizedBox(height: 16),
              _MarketCard(
                title: '₿ Crypto Market',
                subtitle:
                    'Bitcoin • Ethereum • Altcoins • Crypto News • Market Data',
                icon: Icons.currency_bitcoin,
                selected: _selected == 'crypto',
                accent: AppColors.brandOrange,
                onTap: () => setState(() => _selected = 'crypto'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _continue,
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onPrimary,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _selected == 'crypto'
                            ? 'Continue to Crypto Market'
                            : 'Continue to Indian Market',
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? accent : p.borderLight,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.typeCardTitle(17)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.typeSecondary(13)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? accent : p.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
