import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/api/bullwave_api.dart';
import '../../../../core/charts/lightweight_chart.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../models/stock_model.dart';
import '../utils/option_trading_flow.dart';

/// Compact candlestick for an option contract's underlying (or a paper
/// premium path when live candles are unavailable).
class OptionContractChart extends StatefulWidget {
  const OptionContractChart({
    super.key,
    required this.contract,
    required this.chainContext,
    this.height = 200,
  });

  final OptionContractModel contract;
  final OptionChainContext chainContext;
  final double height;

  @override
  State<OptionContractChart> createState() => _OptionContractChartState();
}

class _OptionContractChartState extends State<OptionContractChart> {
  static const _periods = ['1H', '1D', '1W'];

  String _period = '1D';
  bool _loading = true;
  bool _live = false;
  List<CandleModel> _candles = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OptionContractChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sameContract =
        oldWidget.contract.tradeUnderlying == widget.contract.tradeUnderlying &&
        oldWidget.contract.type == widget.contract.type &&
        oldWidget.contract.strike == widget.contract.strike &&
        oldWidget.chainContext.assetClass == widget.chainContext.assetClass;
    if (!sameContract) _load();
  }

  String get _underlyingId {
    final raw = widget.contract.tradeUnderlying.trim();
    switch (widget.chainContext.assetClass) {
      case 'crypto':
        return raw.toLowerCase();
      case 'forex':
        return raw.toLowerCase().replaceAll('/', '').replaceAll('-', '');
      case 'commodity':
        return raw.toLowerCase();
      default:
        return _equityCandleSymbol(raw);
    }
  }

  String get _chartLabel {
    switch (widget.chainContext.assetClass) {
      case 'crypto':
        return _cryptoTicker(_underlyingId);
      case 'forex':
        return _forexTicker(_underlyingId);
      default:
        return _underlyingId.toUpperCase();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    List<CandleModel> live = const [];
    try {
      live = await _fetchLive();
    } catch (_) {
      live = const [];
    }
    if (!mounted) return;
    if (live.length >= 2) {
      setState(() {
        _candles = live;
        _live = true;
        _loading = false;
      });
      return;
    }
    setState(() {
      _candles = _syntheticPremiumPath(
        widget.contract.ltp,
        period: _period,
      );
      _live = false;
      _loading = false;
    });
  }

  Future<List<CandleModel>> _fetchLive() async {
    final api = BullwaveApi.instance;
    final id = _underlyingId;
    switch (widget.chainContext.assetClass) {
      case 'crypto':
        final chart = await api.getCryptoChart(id, period: _period);
        return chart.candles;
      case 'forex':
        final chart = await api.getForexChart(id, period: _period);
        return [
          for (final c in chart.candles)
            CandleModel(
              time: c.time,
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
              volume: c.volume.isFinite
                  ? c.volume.round().clamp(0, 2147483647).toInt()
                  : 0,
            ),
        ];
      case 'commodity':
        // No dedicated commodity candle API — fall through to premium path.
        return const [];
      default:
        return api.getCandles(id, interval: _equityInterval(_period), fast: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final caption = _live
        ? 'Underlying · live'
        : 'Premium path · paper';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _chartLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      caption,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final period in _periods)
                    _PeriodChip(
                      label: period,
                      selected: _period == period,
                      onTap: () {
                        if (_period == period) return;
                        setState(() => _period = period);
                        _load();
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: const Color(0xFF0B0E11),
              child: _loading && _candles.length < 2
                  ? SizedBox(
                      height: widget.height,
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : LightweightMarketChart(
                      symbol: _chartLabel,
                      intervalLabel: _period,
                      candles: _candles,
                      height: widget.height,
                      showVolume: false,
                      lastPrice: widget.contract.ltp,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brandPrimary.withValues(alpha: 0.22)
              : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.brandPrimary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.brandPrimaryLight : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

String _equityCandleSymbol(String raw) {
  final upper = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  if (upper.contains('BANKNIFTY')) return 'BANKNIFTY';
  if (upper.contains('FINNIFTY')) return 'FINNIFTY';
  if (upper.contains('MIDCPNIFTY')) return 'MIDCPNIFTY';
  if (upper.contains('BANKEX')) return 'BANKEX';
  if (upper.contains('SENSEX')) return 'SENSEX';
  if (upper.contains('NIFTY')) return 'NIFTY';
  return upper.isEmpty ? 'NIFTY' : upper;
}

String _equityInterval(String period) {
  switch (period) {
    case '1H':
      return '1h';
    case '1W':
      return '1d';
    default:
      return '1d';
  }
}

String _cryptoTicker(String id) {
  const map = {
    'bitcoin': 'BTC',
    'ethereum': 'ETH',
    'solana': 'SOL',
    'ripple': 'XRP',
    'binancecoin': 'BNB',
  };
  return map[id] ?? id.toUpperCase();
}

String _forexTicker(String id) {
  final clean = id.replaceAll('/', '').toUpperCase();
  if (clean.length == 6) {
    return '${clean.substring(0, 3)}/${clean.substring(3)}';
  }
  return clean;
}

List<CandleModel> _syntheticPremiumPath(
  double ltp, {
  required String period,
}) {
  final base = ltp > 0 ? ltp : 1.0;
  final count = 48;
  final step = switch (period) {
    '1H' => const Duration(minutes: 15),
    '1W' => const Duration(hours: 4),
    _ => const Duration(hours: 1),
  };
  final now = DateTime.now();
  var close = base * 0.94;
  final candles = <CandleModel>[];
  for (var i = count; i >= 1; i--) {
    final open = close;
    final wave = math.sin(i / 5.5) * base * 0.04;
    final noise = math.sin(i * 1.73) * base * 0.012;
    close = i == 1
        ? base
        : (base * 0.94 + wave + noise).clamp(base * 0.45, base * 1.55);
    final high = math.max(open, close) * 1.01;
    final low = math.min(open, close) * 0.99;
    candles.add(
      CandleModel(
        time: now.subtract(step * i),
        open: open,
        high: high,
        low: low,
        close: close,
        volume: 800 + i * 21,
      ),
    );
  }
  return candles;
}
