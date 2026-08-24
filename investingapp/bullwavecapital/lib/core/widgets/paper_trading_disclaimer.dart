import 'package:flutter/material.dart';

import '../config/paper_only_mode.dart';
import '../theme/theme_a.dart';

/// Persistent banner for Phase 1 paper-trading builds.
class PaperTradingDisclaimer extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const PaperTradingDisclaimer({super.key, this.margin, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (!PaperOnlyMode.enabled) return const SizedBox.shrink();

    final p = context.palette;
    return Container(
      width: double.infinity,
      margin: margin ?? EdgeInsets.zero,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: p.primarySoft,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        border: Border.all(color: p.primaryBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: compact ? 16 : 18,
            color: p.primaryDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              PaperOnlyMode.disclaimer,
              style: ThemeAType.label(
                size: compact ? 11 : 12,
                color: p.primaryDark,
              ).copyWith(height: 1.35, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
