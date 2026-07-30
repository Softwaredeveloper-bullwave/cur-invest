import 'package:flutter/material.dart';

import '../../../../core/charts/lightweight_chart.dart';

class PremiumChartToolbar extends StatelessWidget {
  final MarketChartType chartType;
  final ValueChanged<MarketChartType> onChartTypeChanged;
  final bool showVolume;
  final ValueChanged<bool> onVolumeChanged;
  final bool showSma;
  final ValueChanged<bool> onSmaChanged;
  final VoidCallback onFullscreen;

  const PremiumChartToolbar({
    super.key,
    required this.chartType,
    required this.onChartTypeChanged,
    required this.showVolume,
    required this.onVolumeChanged,
    required this.showSma,
    required this.onSmaChanged,
    required this.onFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFF5F5F0) : const Color(0xFF151513);
    final muted = dark ? const Color(0xFFAAA9A2) : const Color(0xFF666660);
    final surface = dark ? const Color(0xFF11110F) : const Color(0xFFF8F8F4);
    final border = dark ? const Color(0xFF292925) : const Color(0xFFE3E3DC);

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          PopupMenuButton<MarketChartType>(
            initialValue: chartType,
            tooltip: 'Chart type',
            onSelected: onChartTypeChanged,
            itemBuilder: (_) => MarketChartType.values
                .map(
                  (type) =>
                      PopupMenuItem(value: type, child: Text(_label(type))),
                )
                .toList(growable: false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(_icon(chartType), size: 17, color: foreground),
                  const SizedBox(width: 7),
                  Text(
                    _label(chartType),
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.expand_more_rounded, size: 16, color: muted),
                ],
              ),
            ),
          ),
          VerticalDivider(width: 1, color: border, indent: 9, endIndent: 9),
          _ToggleButton(
            label: 'Volume',
            selected: showVolume,
            onTap: () => onVolumeChanged(!showVolume),
          ),
          _ToggleButton(
            label: 'SMA',
            selected: showSma,
            onTap: () => onSmaChanged(!showSma),
          ),
          const Spacer(),
          IconButton(
            onPressed: onFullscreen,
            tooltip: 'Fullscreen chart',
            icon: Icon(Icons.open_in_full_rounded, size: 17, color: foreground),
          ),
        ],
      ),
    );
  }

  static String _label(MarketChartType type) => switch (type) {
    MarketChartType.candlestick => 'Candles',
    MarketChartType.line => 'Line',
    MarketChartType.area => 'Area',
  };

  static IconData _icon(MarketChartType type) => switch (type) {
    MarketChartType.candlestick => Icons.candlestick_chart_rounded,
    MarketChartType.line => Icons.show_chart_rounded,
    MarketChartType.area => Icons.area_chart_rounded,
  };
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFC6FF00).withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: selected
                  ? const Color(0xFFC6FF00).withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFFC6FF00)
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
