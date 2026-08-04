import 'package:flutter/material.dart';

import '../theme/theme_a.dart';
import 'scale_tap.dart';

class ShellHighlightAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const ShellHighlightAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

/// Horizontal quick-access row for shell tabs — matches home quick actions.
class ShellHighlightActionsRow extends StatelessWidget {
  final List<ShellHighlightAction> actions;

  const ShellHighlightActionsRow({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _ActionTile(action: actions[index]),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final ShellHighlightAction action;

  const _ActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ScaleTap(
      onTap: action.onTap,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: action.color.withValues(alpha: 0.28)),
                boxShadow: [
                  BoxShadow(
                    color: action.color.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(action.icon, size: 20, color: action.color),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              style: context.typeLabel(11),
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
