import 'package:flutter/material.dart';

import '../../../../core/charts/lightweight_chart.dart';

/// Compact Dhan-style chart controls (type, volume, indicators).
class DhanChartToolbar extends StatelessWidget {
  final MarketChartType chartType;
  final ValueChanged<MarketChartType> onChartTypeChanged;
  final bool showVolume;
  final ValueChanged<bool> onVolumeChanged;
  final bool showSma;
  final ValueChanged<bool> onSmaChanged;

  const DhanChartToolbar({
    super.key,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.showVolume,
    required this.onVolumeChanged,
    required this.showSma,
    required this.onSmaChanged,
  });

  static const _muted = Color(0xFF8B949E);
  static const _active = Color(0xFF00C853);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
      child: Row(
        children: [
          _typeChip(
            'Candles',
            MarketChartType.candlestick,
            Icons.candlestick_chart_rounded,
          ),
          const SizedBox(width: 4),
          _typeChip('Line', MarketChartType.line, Icons.show_chart_rounded),
          const SizedBox(width: 4),
          _typeChip('Area', MarketChartType.area, Icons.area_chart_rounded),
          const Spacer(),
          _toggle('Vol', showVolume, onVolumeChanged),
          const SizedBox(width: 4),
          _toggle('SMA', showSma, onSmaChanged),
        ],
      ),
    );
  }

  Widget _typeChip(String label, MarketChartType type, IconData icon) {
    final selected = chartType == type;
    return InkWell(
      onTap: () => onChartTypeChanged(type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? _active.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? _active.withValues(alpha: 0.45)
                : const Color(0xFF1E2329),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? _active : _muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? _active : _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(String label, bool on, ValueChanged<bool> changed) {
    return InkWell(
      onTap: () => changed(!on),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: on ? _active.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: on
                ? _active.withValues(alpha: 0.45)
                : const Color(0xFF1E2329),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: on ? _active : _muted,
          ),
        ),
      ),
    );
  }
}

/// OHLC + volume strip shown above the chart (updates on crosshair).
class ChartOhlcStrip extends StatelessWidget {
  final String? open;
  final String? high;
  final String? low;
  final String? close;
  final String? volume;
  final bool isBullish;

  const ChartOhlcStrip({
    super.key,
    this.open,
    this.high,
    this.low,
    this.close,
    this.volume,
    this.isBullish = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 2),
      child: Row(
        children: [
          _cell('O', open),
          _cell('H', high, const Color(0xFF00C853)),
          _cell('L', low, const Color(0xFFEF5350)),
          _cell(
            'C',
            close,
            isBullish ? const Color(0xFF00C853) : const Color(0xFFEF5350),
          ),
          if (volume != null) ...[
            const Spacer(),
            Text(
              'Vol $volume',
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cell(String key, String? value, [Color? color]) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 10, fontFamily: 'Inter'),
          children: [
            TextSpan(
              text: '$key ',
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value ?? '—',
              style: TextStyle(
                color: color ?? const Color(0xFFE6EDF3),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
