import 'package:flutter/material.dart';

import '../../../../core/constants/goal_template_icons.dart';

class GoalTemplateIcon extends StatelessWidget {
  final String category;
  final Color color;
  final double size;
  final String? legacyIcon;

  const GoalTemplateIcon({
    super.key,
    required this.category,
    required this.color,
    this.size = 42,
    this.legacyIcon,
  });

  @override
  Widget build(BuildContext context) {
    final icon = legacyIcon != null
        ? GoalTemplateIcons.fromLegacy(legacyIcon!, category)
        : GoalTemplateIcons.forCategory(category);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.34),
            color.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.38)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}
