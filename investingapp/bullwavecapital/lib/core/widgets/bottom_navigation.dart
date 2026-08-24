import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/colors.dart';

/// Floating pill bottom nav — active tab highlighted inside the bar (no notch).
class AppBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const barHeight = 64.0;
  static const cornerRadius = 32.0;
  static const horizontalInset = 20.0;
  static const activeCapsuleHeight = 44.0;
  static const activeCapsuleWidth = 52.0;

  static double get totalHeight => barHeight;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _NavItem {
  const _NavItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const _items = [
    _NavItem(PhosphorIcons.house, 'Home'),
    _NavItem(PhosphorIcons.chartLineUp, 'Markets'),
    _NavItem(PhosphorIcons.chartPie, 'Portfolio'),
    _NavItem(PhosphorIcons.wallet, 'Wallet'),
    _NavItem(PhosphorIcons.user, 'Profile'),
  ];

  late AnimationController _controller;
  late double _fromIndex;
  late double _toIndex;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex.toDouble();
    _toIndex = widget.currentIndex.toDouble();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..value = 1;
  }

  @override
  void didUpdateWidget(covariant AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromIndex = _animatedIndex;
      _toIndex = widget.currentIndex.toDouble();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _animatedIndex {
    final t = Curves.easeInOutCubic.transform(_controller.value);
    return lerpDouble(_fromIndex, _toIndex, t)!;
  }

  void _onTap(int index) {
    if (index == widget.currentIndex) return;
    HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppBottomNavigation.horizontalInset,
        0,
        AppBottomNavigation.horizontalInset,
        bottomPad + 8,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SizedBox(
            height: AppBottomNavigation.barHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final slot = width / _items.length;
                final cx = slot * _animatedIndex + slot / 2;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Soft shadow under floating pill
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppBottomNavigation.cornerRadius,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.08,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pill background
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(
                            AppBottomNavigation.cornerRadius,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                    ),

                    // Sliding active capsule (Pinterest-style)
                    Positioned(
                      left: cx - AppBottomNavigation.activeCapsuleWidth / 2,
                      top: (AppBottomNavigation.barHeight -
                              AppBottomNavigation.activeCapsuleHeight) /
                          2,
                      width: AppBottomNavigation.activeCapsuleWidth,
                      height: AppBottomNavigation.activeCapsuleHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.navHomeGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brandPrimary.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Nav items
                    Row(
                      children: List.generate(_items.length, (i) {
                        final active = i == widget.currentIndex;
                        final item = _items[i];
                        return Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onTap(i),
                              borderRadius: BorderRadius.circular(22),
                              child: SizedBox(
                                height: AppBottomNavigation.barHeight,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: active ? 22 : 21,
                                      color: active
                                          ? AppColors.onBrandPrimary
                                          : Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: active
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: active
                                            ? AppColors.onBrandPrimary
                                            : Colors.white.withValues(
                                                alpha: 0.5,
                                              ),
                                        height: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
