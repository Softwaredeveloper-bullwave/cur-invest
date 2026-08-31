import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/routes.dart';
import 'ai_orb_widgets.dart';

/// Floating AI buddy button — glassmorphism avatar tile.
class AiAssistantFab extends StatefulWidget {
  final double bottom;
  final double right;

  const AiAssistantFab({super.key, this.bottom = 24, this.right = 16});

  @override
  State<AiAssistantFab> createState() => _AiAssistantFabState();
}

class _AiAssistantFabState extends State<AiAssistantFab>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(AppRoutes.aiAssistant)) {
      return const SizedBox.shrink();
    }

    // Match AppBottomNavigation: pill + 8px lift + home-indicator inset.
    final navInset = MediaQuery.paddingOf(context).bottom;
    const fabSize = 56.0;
    final radius = fabSize * 0.28;

    return Positioned(
      right: widget.right,
      bottom: widget.bottom + navInset,
      width: fabSize,
      height: fabSize,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final t = _pulse.value;
          return Transform.translate(
            offset: Offset(0, (t - 0.5) * 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF38BDF8,
                    ).withValues(alpha: 0.18 + t * 0.08),
                    blurRadius: 12,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(AppRoutes.aiAssistant),
            borderRadius: BorderRadius.circular(radius),
            child: const AiOrbLogo(
              size: fabSize,
              showArc: false,
              animate: true,
              showName: true,
            ),
          ),
        ),
      ),
    );
  }
}
