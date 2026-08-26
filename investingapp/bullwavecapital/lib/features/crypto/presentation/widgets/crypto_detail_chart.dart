import 'package:flutter/material.dart';

import '../../../../core/charts/lightweight_chart.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../models/stock_model.dart';
import '../../../stocks/presentation/widgets/dhan_chart_toolbar.dart';

/// Crypto chart periods shown in UI (aligned with backend CoinDCX periods).
const cryptoChartIntervals = <String>['1H', '1D', '1W', '1M', '3M', '1Y', 'ALL'];

const Color _chartBg = Color(0xFF0B0E11);
const Color _chartBorder = Color(0xFF1E2329);

/// Same visual language as Indian [StockDetailChart] — candlestick / line / area
/// with pinch-zoom, pan, SMA / EMA / Bollinger overlays.
class CryptoDetailChart extends StatefulWidget {
  const CryptoDetailChart({
    super.key,
    required this.symbol,
    required this.candles,
    required this.isLoading,
    required this.selectedPeriod,
    required this.onPeriodSelected,
    this.lastPrice,
  });

  final String symbol;
  final List<CandleModel> candles;
  final bool isLoading;
  final String selectedPeriod;
  final ValueChanged<String> onPeriodSelected;
  final double? lastPrice;

  @override
  State<CryptoDetailChart> createState() => _CryptoDetailChartState();
}

class _CryptoDetailChartState extends State<CryptoDetailChart> {
  MarketChartType _chartType = MarketChartType.candlestick;
  bool _showVolume = true;
  bool _showSma = false;
  bool _showEma = false;
  bool _showBollinger = false;
  CandleModel? _crosshairCandle;

  CandleModel? get _displayCandle {
    if (_crosshairCandle != null) return _crosshairCandle;
    if (widget.candles.isEmpty) return null;
    return widget.candles.last;
  }

  String _formatVol(int vol) {
    if (vol >= 1000000000) return '${(vol / 1000000000).toStringAsFixed(2)}B';
    if (vol >= 1000000) return '${(vol / 1000000).toStringAsFixed(2)}M';
    if (vol >= 1000) return '${(vol / 1000).toStringAsFixed(1)}K';
    return vol.toString();
  }

  String _formatPx(double v) {
    if (v >= 1000) return IndexFormatter.format(v);
    if (v >= 1) return v.toStringAsFixed(2);
    return v.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    final candle = _displayCandle;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth >= 700
            ? 360.0
            : constraints.maxWidth < 380
                ? 260.0
                : 310.0;

        return Container(
          decoration: BoxDecoration(
            color: _chartBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _chartBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: cryptoChartIntervals.map((label) {
                      final selected = label == widget.selectedPeriod;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          onTap: () => widget.onPeriodSelected(label),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF00C853).withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected
                                    ? const Color(0xFF00C853)
                                    : const Color(0xFF8B949E),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              DhanChartToolbar(
                chartType: _chartType,
                onChartTypeChanged: (v) => setState(() => _chartType = v),
                showVolume: _showVolume,
                onVolumeChanged: (v) => setState(() => _showVolume = v),
                showSma: _showSma,
                onSmaChanged: (v) => setState(() => _showSma = v),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _IndicatorChip(
                      label: 'EMA 20',
                      selected: _showEma,
                      color: const Color(0xFFE879F9),
                      onTap: () => setState(() => _showEma = !_showEma),
                    ),
                    _IndicatorChip(
                      label: 'BB 20',
                      selected: _showBollinger,
                      color: const Color(0xFF8B949E),
                      onTap: () =>
                          setState(() => _showBollinger = !_showBollinger),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, top: 6),
                      child: Text(
                        'Pinch or +/− to zoom · drag to pan',
                        style: TextStyle(color: Color(0xFF8B949E), fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              ChartOhlcStrip(
                open: candle != null ? _formatPx(candle.open) : null,
                high: candle != null ? _formatPx(candle.high) : null,
                low: candle != null ? _formatPx(candle.low) : null,
                close: candle != null ? _formatPx(candle.close) : null,
                volume: candle != null ? _formatVol(candle.volume) : null,
                isBullish: candle?.isBullish ?? true,
              ),
              SizedBox(
                height: chartHeight,
                child: Stack(
                  children: [
                    if (widget.candles.isEmpty && !widget.isLoading)
                      const Center(
                        child: Text(
                          'Chart unavailable for this period',
                          style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
                        ),
                      )
                    else
                      LightweightMarketChart(
                        symbol: widget.symbol,
                        intervalLabel: widget.selectedPeriod,
                        candles: widget.candles,
                        height: chartHeight,
                        chartType: _chartType,
                        showVolume: _showVolume,
                        showSma: _showSma,
                        showEma: _showEma,
                        showBollinger: _showBollinger,
                        lastPrice: widget.lastPrice,
                        onCrosshair: (c) => setState(() => _crosshairCandle = c),
                      ),
                    if (widget.isLoading)
                      const Positioned.fill(
                        child: ColoredBox(
                          color: Color(0x880B0E11),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00C853),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IndicatorChip extends StatelessWidget {
  const _IndicatorChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.6) : const Color(0xFF1E2329),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: selected ? color : const Color(0xFF8B949E),
          ),
        ),
      ),
    );
  }
}
