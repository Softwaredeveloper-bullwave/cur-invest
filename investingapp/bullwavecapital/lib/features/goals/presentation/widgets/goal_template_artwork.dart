import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Thematic illustration for each goal template card.
class GoalTemplateArtwork extends StatelessWidget {
  final String category;
  final Color color;

  const GoalTemplateArtwork({
    super.key,
    required this.category,
    required this.color,
  });

  static String assetForCategory(String category) {
    switch (category) {
      case 'house':
        return 'assets/svg/goal_house.svg';
      case 'retirement':
        return 'assets/svg/goal_retirement.svg';
      case 'education':
        return 'assets/svg/goal_education.svg';
      case 'marriage':
        return 'assets/svg/goal_marriage.svg';
      case 'vehicle':
        return 'assets/svg/goal_vehicle.svg';
      default:
        return 'assets/svg/goal_house.svg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.1,
          colors: [
            color.withValues(alpha: 0.16),
            color.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -12,
            bottom: -6,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SvgPicture.asset(
              assetForCategory(category),
              fit: BoxFit.contain,
              alignment: Alignment.center,
            ),
          ),
        ],
      ),
    );
  }
}
