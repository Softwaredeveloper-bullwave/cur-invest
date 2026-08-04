import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Reliable goal category icons (Phosphor — works on all platforms).
class GoalTemplateIcons {
  GoalTemplateIcons._();

  static IconData forCategory(String category) {
    switch (category) {
      case 'house':
        return PhosphorIconsFill.house;
      case 'retirement':
        return PhosphorIconsFill.armchair;
      case 'education':
        return PhosphorIconsFill.graduationCap;
      case 'marriage':
        return PhosphorIconsFill.heart;
      case 'vehicle':
        return PhosphorIconsFill.car;
      default:
        return PhosphorIconsFill.target;
    }
  }

  /// Fallback when only legacy API icon strings are available.
  static IconData fromLegacy(String icon, String category) {
    switch (icon) {
      case 'home':
      case 'house':
        return PhosphorIconsFill.house;
      case 'elderly':
      case 'retirement':
        return PhosphorIconsFill.armchair;
      case 'school':
      case 'education':
        return PhosphorIconsFill.graduationCap;
      case 'favorite':
      case 'marriage':
        return PhosphorIconsFill.heart;
      case 'directions_car':
      case 'vehicle':
      case 'car':
        return PhosphorIconsFill.car;
      default:
        return forCategory(category);
    }
  }
}
