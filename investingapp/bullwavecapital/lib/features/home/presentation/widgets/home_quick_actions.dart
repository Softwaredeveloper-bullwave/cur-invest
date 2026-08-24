import 'package:flutter/material.dart';

import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/scale_tap.dart';

class HomeQuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const HomeQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class HomePrimaryActionsRow extends StatelessWidget {
  final List<HomeQuickAction> actions;

  const HomePrimaryActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return HomeQuickActionsCarousel(actions: actions);
  }
}

/// Horizontally scrollable quick actions — cleaner than cramped 5-column rows.
class HomeQuickActionsCarousel extends StatelessWidget {
  final List<HomeQuickAction> actions;
  final bool compact;

  const HomeQuickActionsCarousel({
    super.key,
    required this.actions,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 88 : 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _CarouselActionTile(action: actions[index], compact: compact);
        },
      ),
    );
  }
}

class HomeSecondaryActionsRow extends StatelessWidget {
  final List<HomeQuickAction> actions;

  const HomeSecondaryActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    return HomeQuickActionsCarousel(actions: actions, compact: true);
  }
}

class _CarouselActionTile extends StatelessWidget {
  final HomeQuickAction action;
  final bool compact;

  const _CarouselActionTile({required this.action, required this.compact});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = compact ? 44.0 : 50.0;

    return ScaleTap(
      onTap: action.onTap,
      child: SizedBox(
        width: compact ? 68 : 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: action.color.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: action.color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                action.icon,
                size: compact ? 20 : 22,
                color: action.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: context.typeLabel(compact ? 11 : 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
