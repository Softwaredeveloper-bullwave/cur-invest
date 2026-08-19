import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/colors.dart';

/// Figma-style floating bottom nav — concave notch, centered blue bubble.
class AppBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const bubbleRadius = 28.0;
  static const barHeight = 62.0;
  static const cornerRadius = 31.0;
  static const horizontalInset = 18.0;

  /// Protrusion above bar top (half bubble + small gap).
  static const topProtrusion = bubbleRadius + 4.0;

  static double get totalHeight => barHeight + topProtrusion;

  /// Bubble center sits in the middle of the notch valley (between lip & dip).
  static double bubbleCenterFromBarBottom(double R) => barHeight - R * 0.5;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const _items = [
    PhosphorIcons.house,
    PhosphorIcons.chartLineUp,
    PhosphorIcons.chartPie,
    PhosphorIcons.wallet,
    PhosphorIcons.user,
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
      duration: const Duration(milliseconds: 360),
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
    const R = AppBottomNavigation.bubbleRadius;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppBottomNavigation.horizontalInset,
        0,
        AppBottomNavigation.horizontalInset,
        bottomPad + 6,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return SizedBox(
            height: AppBottomNavigation.totalHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final slot = width / _items.length;
                final cx = slot * _animatedIndex + slot / 2;
                final bubbleCenterY =
                    AppBottomNavigation.bubbleCenterFromBarBottom(R);
                final bubbleBottom = bubbleCenterY - R;

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Shadow only under the pill (not full-width band)
                    Positioned(
                      left: 2,
                      right: 2,
                      bottom: 0,
                      height: AppBottomNavigation.barHeight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppBottomNavigation.cornerRadius,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Pill bar + notch
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: AppBottomNavigation.barHeight,
                      child: CustomPaint(
                        painter: _FigmaBarPainter(
                          centerX: cx,
                          bubbleRadius: R,
                          cornerRadius: AppBottomNavigation.cornerRadius,
                          barColor: AppColors.surfaceSecondary,
                        ),
                      ),
                    ),

                    // Inactive icons
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: AppBottomNavigation.barHeight,
                      child: Row(
                        children: List.generate(_items.length, (i) {
                          if (i == widget.currentIndex) {
                            return const Expanded(child: SizedBox());
                          }
                          return Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _onTap(i),
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: Icon(
                                    _items[i],
                                    size: 23,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Bubble centered in notch
                    Positioned(
                      left: cx - R,
                      bottom: bubbleBottom,
                      width: R * 2,
                      height: R * 2,
                      child: GestureDetector(
                        onTap: () => _onTap(widget.currentIndex),
                        behavior: HitTestBehavior.opaque,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.navHomeGradient,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandPrimary.withValues(alpha: 0.45),
                                blurRadius: 14,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              _items[widget.currentIndex],
                              size: 24,
                              color: AppColors.onBrandPrimary,
                            ),
                          ),
                        ),
                      ),
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

class _FigmaBarPainter extends CustomPainter {
  _FigmaBarPainter({
    required this.centerX,
    required this.bubbleRadius,
    required this.cornerRadius,
    required this.barColor,
  });

  final double centerX;
  final double bubbleRadius;
  final double cornerRadius;
  final Color barColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final R = bubbleRadius;
    final cx = centerX.clamp(r + R + 2, w - r - R - 2);

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(cx - R, 0)
      ..arcToPoint(
        Offset(cx + R, 0),
        radius: Radius.circular(R),
        clockwise: false,
      )
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(path, Paint()..color = barColor);
  }

  @override
  bool shouldRepaint(covariant _FigmaBarPainter oldDelegate) {
    return oldDelegate.centerX != centerX;
  }
}
