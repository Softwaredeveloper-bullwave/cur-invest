import 'package:flutter/material.dart';

import 'theme_a.dart';

class AppDecorations {
  AppDecorations._();

  static BoxDecoration heroCard(BuildContext context) {
    return context.palette.cardDecoration(radius: 28);
  }

  static BoxDecoration iconBadge(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
    );
  }

  static BoxDecoration card(
    BuildContext context, {
    Color? color,
    bool glow = false,
    Color? glowColor,
    bool premium = false,
  }) {
    final p = context.palette;
    return p.cardDecoration(
      shadowTint: glow ? (glowColor ?? p.primary) : p.primary,
      radius: premium ? 28 : 24,
    );
  }

  static BoxDecoration premiumTile(
    BuildContext context, {
    required Color accent,
  }) {
    return context.palette.cardDecoration(shadowTint: accent, radius: 24);
  }

  static BoxDecoration glassCard(BuildContext context) {
    return context.palette.cardDecoration(radius: 24);
  }

  static InputDecoration pillSearch(BuildContext context, {String? hint}) {
    final p = context.palette;
    return InputDecoration(
      hintText: hint ?? 'Search',
      hintStyle: TextStyle(color: p.textGrey, fontSize: 14),
      filled: true,
      fillColor: p.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      prefixIcon: Icon(Icons.search_rounded, color: p.textGrey, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: p.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: p.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(999),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    );
  }
}
