import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'home_theme_a.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  final String hint;

  const HomeSearchBar({
    super.key,
    required this.onTap,
    this.hint = 'Search stocks, indices & F&O',
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: p.card.withValues(alpha: 0.9),
            border: Border.all(color: p.primary.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: p.primary.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: p.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    PhosphorIcons.magnifyingGlass,
                    size: 18,
                    color: p.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hint,
                    style: ThemeAType.secondary(size: 14, color: p.textGrey),
                  ),
                ),
                Icon(
                  PhosphorIcons.slidersHorizontal,
                  size: 16,
                  color: p.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
