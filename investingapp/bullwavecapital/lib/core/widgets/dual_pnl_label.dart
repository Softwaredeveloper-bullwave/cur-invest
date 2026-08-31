import 'package:flutter/material.dart';

import '../theme/theme_a.dart';
import '../utils/formatters.dart';

/// Live P&L. Crypto and forex show USD and INR; Indian stays in ₹.
class DualPnlLabel extends StatelessWidget {
  const DualPnlLabel({
    super.key,
    required this.pnlInr,
    this.percent,
    this.usdInr,
    this.showUsd = false,
    this.alignEnd = true,
    this.compact = false,
  });

  final double pnlInr;
  final double? percent;
  final double? usdInr;
  final bool showUsd;
  final bool alignEnd;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = pnlInr >= 0
        ? context.palette.positive
        : context.palette.negative;
    final align = alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: align,
      children: [
        if (showUsd)
          Text(
            CurrencyFormatter.formatDualPnlUsd(pnlInr, usdInr),
            style: context.typeLabel(compact ? 13 : 14, color).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        Text(
          showUsd
              ? CurrencyFormatter.formatDualPnlInr(pnlInr)
              : CurrencyFormatter.formatSignedInr(pnlInr),
          style: context
              .typeLabel(
                showUsd ? 11 : (compact ? 13 : 14),
                color,
              )
              .copyWith(fontWeight: showUsd ? FontWeight.w600 : FontWeight.w800),
        ),
        if (percent != null)
          Text(
            IndexFormatter.formatPercent(percent!),
            style: context.typeLabel(11, color),
          ),
      ],
    );
  }
}
