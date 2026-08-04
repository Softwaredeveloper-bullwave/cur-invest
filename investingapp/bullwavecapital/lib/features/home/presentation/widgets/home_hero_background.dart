import 'package:flutter/material.dart';

import '../../../../core/widgets/page_hero_background.dart';

export '../../../../core/widgets/page_hero_background.dart';

/// Home hero wrapper — uses shared [PageHeroBackground].
class HomeHeroBackground extends StatelessWidget {
  final Widget child;

  const HomeHeroBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => PageHeroBackground(child: child);
}
