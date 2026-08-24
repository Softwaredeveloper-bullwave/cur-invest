import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/colors.dart';
import '../utils/formatters.dart';

enum ExpiryHighlightStyle {
  /// Solid blue pill — home cards, tight spaces.
  compact,

  /// Bordered chip — summary rows.
  chip,

  /// Larger badge with icon — headers and trading pads.
  banner,
}

/// Consistent highlighted F&O expiry badge across the app.
class ExpiryHighlight extends StatelessWidget {
  final String expiryIso;
  final ExpiryHighlightStyle style;
  final bool showPrefix;

  const ExpiryHighlight({
    super.key,
    required this.expiryIso,
    this.style = ExpiryHighlightStyle.chip,
    this.showPrefix = true,
  });

  factory ExpiryHighlight.fromDateTime(
    DateTime expiry, {
    ExpiryHighlightStyle style = ExpiryHighlightStyle.chip,
    bool showPrefix = true,
  }) {
    return ExpiryHighlight(
      expiryIso: expiry.toIso8601String().substring(0, 10),
      style: style,
      showPrefix: showPrefix,
    );
  }

  String get _label {
    final formatted = DateFormatter.expiryLabel(expiryIso);
    return showPrefix ? 'Exp $formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case ExpiryHighlightStyle.compact:
        return _buildCompact();
      case ExpiryHighlightStyle.chip:
        return _buildChip(filled: false);
      case ExpiryHighlightStyle.banner:
        return _buildChip(filled: true, withIcon: true);
    }
  }

  Widget _buildCompact() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.onBrandPrimary,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildChip({required bool filled, bool withIcon = false}) {
    final bg = filled
        ? AppColors.brandPrimary
        : AppColors.brandPrimary.withValues(alpha: 0.16);
    final fg = filled ? AppColors.onBrandPrimary : AppColors.brandPrimaryDark;
    final border = filled
        ? AppColors.brandPrimary
        : AppColors.brandPrimary.withValues(alpha: 0.55);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: withIcon ? 10 : 9,
        vertical: withIcon ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: filled ? 1.5 : 1),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (withIcon) ...[
            Icon(PhosphorIcons.calendarBlank, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            _label,
            style: TextStyle(
              color: fg,
              fontSize: withIcon ? 12 : 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable expiry pill for horizontal expiry selectors.
class ExpirySelectorChip extends StatelessWidget {
  final String expiryIso;
  final bool selected;
  final VoidCallback? onTap;

  const ExpirySelectorChip({
    super.key,
    required this.expiryIso,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: ExpiryHighlight(
            expiryIso: expiryIso,
            style: ExpiryHighlightStyle.banner,
            showPrefix: false,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceSecondary.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Text(
            DateFormatter.expiryLabel(expiryIso),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}
