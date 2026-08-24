import 'package:flutter/material.dart';

import '../theme/theme_a.dart';

/// Soft lime gradient + glow orbs behind shell tab hero content.
class PageHeroBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PageHeroBackground({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.bg,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            p.primarySoft.withValues(alpha: p.isDark ? 0.55 : 0.35),
            p.bg,
            p.bg,
          ],
          stops: const [0.0, 0.42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.primary.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: 80,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      ),
    );
  }
}
