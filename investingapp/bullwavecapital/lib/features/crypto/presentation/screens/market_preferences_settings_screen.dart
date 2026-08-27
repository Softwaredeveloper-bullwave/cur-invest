import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../provider/crypto_market_provider.dart';

/// One market at a time: Indian XOR Crypto.
class MarketPreferencesSettingsScreen extends StatefulWidget {
  const MarketPreferencesSettingsScreen({super.key});

  @override
  State<MarketPreferencesSettingsScreen> createState() =>
      _MarketPreferencesSettingsScreenState();
}

class _MarketPreferencesSettingsScreenState
    extends State<MarketPreferencesSettingsScreen> {
  /// `indian` | `crypto`
  String _selected = 'indian';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final provider = context.read<CryptoMarketProvider>();
    await provider.loadPreference();
    if (!mounted) return;
    final pref = provider.preference;
    setState(() {
      if (pref?.forexMarketEnabled == true || provider.activeMarket == 'forex') {
        _selected = 'forex';
      } else if (pref?.cryptoMarketEnabled == true &&
          pref?.indianMarketEnabled != true) {
        _selected = 'crypto';
      } else if (provider.activeMarket == 'crypto') {
        _selected = 'crypto';
      } else {
        _selected = 'indian';
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final provider = context.read<CryptoMarketProvider>();
    final ok = await provider.savePreference(
      indianMarketEnabled: _selected == 'indian',
      cryptoMarketEnabled: _selected == 'crypto',
      forexMarketEnabled: _selected == 'forex',
      activeMarket: _selected,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      AppSnackbar.error(
        context,
        provider.error ??
            'Market data is temporarily unavailable. Please try again.',
      );
      return;
    }
    AppSnackbar.success(context, 'Market preference saved');
    if (_selected == 'crypto') {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: const CustomAppBar(title: 'Market Preferences'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              children: [
                Text(
                  'Choose one market',
                  style: context.typeCardTitle(16),
                ),
                const SizedBox(height: 6),
                Text(
                  'You can use one market at a time. Switch anytime from here or Home.',
                  style: context.typeSecondary(13),
                ),
                const SizedBox(height: 16),
                _MarketOptionTile(
                  title: '🇮🇳 Indian Market',
                  subtitle: 'NSE, BSE, stocks & mutual funds',
                  selected: _selected == 'indian',
                  accent: AppColors.brandPrimary,
                  onTap: () => setState(() => _selected = 'indian'),
                ),
                const SizedBox(height: 12),
                _MarketOptionTile(
                  title: '₿ Crypto Market',
                  subtitle: 'Crypto prices & paper trading',
                  selected: _selected == 'crypto',
                  accent: AppColors.brandOrange,
                  onTap: () => setState(() => _selected = 'crypto'),
                ),
                const SizedBox(height: 12),
                _MarketOptionTile(
                  title: '💱 Forex Market',
                  subtitle: 'FX majors, crosses, USD/INR & paper trading',
                  selected: _selected == 'forex',
                  accent: AppColors.brandCyan,
                  onTap: () => setState(() => _selected = 'forex'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
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
                              ? 'Save & open Crypto Market'
                              : _selected == 'forex'
                                  ? 'Save & open Forex Market'
                                  : 'Save & open Indian Market',
                        ),
                ),
              ],
            ),
    );
  }
}

class _MarketOptionTile extends StatelessWidget {
  const _MarketOptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : p.borderLight,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.typeCardTitle(15)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: context.typeSecondary(13)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? accent : p.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
