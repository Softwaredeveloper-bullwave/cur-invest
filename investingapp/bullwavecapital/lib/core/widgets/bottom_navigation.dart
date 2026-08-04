import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../theme/theme_a.dart';

/// Animated curved bottom bar — sliding lime bubble + top notch (BullWave theme).
class AppBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  static const _items = [
    (PhosphorIcons.house, 'Home'),
    (PhosphorIcons.chartLineUp, 'Markets'),
    (PhosphorIcons.chartPie, 'Portfolio'),
    (PhosphorIcons.wallet, 'Wallet'),
    (PhosphorIcons.user, 'Profile'),
  ];

  static const _barHeight = 62.0;
  static const _bubbleSize = 54.0;
  static const _bubbleLift = 24.0;
  static const _notchSpread = 34.0;
  static const _cornerRadius = 28.0;

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
      duration: const Duration(milliseconds: 420),
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
    final t = Curves.easeOutCubic.transform(_controller.value);
    return lerpDouble(_fromIndex, _toIndex, t) ?? _toIndex;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: SizedBox(
        height: _barHeight + _bubbleLift + 8,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final itemWidth = width / _items.length;
            final centerX = itemWidth * _animatedIndex + itemWidth / 2;
            final bubbleBottom = _barHeight - _bubbleSize * 0.42 + _bubbleLift;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Soft glow under active bubble
                Positioned(
                  left: centerX - 36,
                  bottom: bubbleBottom - 6,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Container(
                        width: 72,
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(40),
                          color: p.primary.withValues(alpha: 0.08),
                          boxShadow: [
                            BoxShadow(
                              color: p.primary.withValues(alpha: p.isDark ? 0.35 : 0.28),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bar + notch
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: _barHeight,
                  child: CustomPaint(
                    painter: _CurvedNavBarPainter(
                      centerX: centerX,
                      notchSpread: _notchSpread,
                      cornerRadius: _cornerRadius,
                      fill: p.card,
                      border: p.borderLight,
                      shadow: p.isDark
                          ? p.primary.withValues(alpha: 0.07)
                          : const Color(0xFF0A0A0A).withValues(alpha: 0.1),
                    ),
                    child: Row(
                      children: List.generate(_items.length, (i) {
                        final active = i == widget.currentIndex;
                        final (_, label) = _items[i];
                        final inactiveColor =
                            p.isDark ? const Color(0xFF9CAAB8) : p.textMuted;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => widget.onTap(i),
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                SizedBox(
                                  height: active ? 26 : 30,
                                  child: active
                                      ? null
                                      : Icon(
                                          _items[i].$1,
                                          size: 22,
                                          color: inactiveColor,
                                        ),
                                ),
                                const SizedBox(height: 2),
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 220),
                                  style: GoogleFonts.inter(
                                    fontSize: active ? 11.5 : 10.5,
                                    fontWeight:
                                        active ? FontWeight.w700 : FontWeight.w500,
                                    color: active ? p.primary : inactiveColor,
                                    height: 1.1,
                                    letterSpacing: active ? 0.15 : 0,
                                  ),
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),

                // Active bubble + icon
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    return Positioned(
                      left: centerX - _bubbleSize / 2,
                      bottom: bubbleBottom,
                      child: GestureDetector(
                        onTap: () => widget.onTap(widget.currentIndex),
                        child: Container(
                          width: _bubbleSize,
                          height: _bubbleSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                p.primary,
                                Color.lerp(p.primary, p.primaryDark, 0.12)!,
                              ],
                            ),
                            border: Border.all(
                              color: p.primary.withValues(alpha: 0.55),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: p.primary.withValues(alpha: 0.45),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(
                            _items[widget.currentIndex].$1,
                            size: 26,
                            color: p.primaryDark,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CurvedNavBarPainter extends CustomPainter {
  _CurvedNavBarPainter({
    required this.centerX,
    required this.notchSpread,
    required this.cornerRadius,
    required this.fill,
    required this.border,
    required this.shadow,
  });

  final double centerX;
  final double notchSpread;
  final double cornerRadius;
  final Color fill;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _barPath(size);
    canvas.drawShadow(path, shadow, 14, false);

    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  Path _barPath(Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final left = centerX - notchSpread;
    final right = centerX + notchSpread;
    const dip = 14.0;

    final path = Path()
      ..moveTo(0, h)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(left, 0);

    // Concave notch hugging the bubble
    path.cubicTo(
      left + 8,
      0,
      centerX - 18,
      dip,
      centerX,
      dip,
    );
    path.cubicTo(
      centerX + 18,
      dip,
      right - 8,
      0,
      right,
      0,
    );

    path
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..close();

    return path;
  }

  @override
  bool shouldRepaint(covariant _CurvedNavBarPainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.fill != fill ||
        oldDelegate.border != border;
  }
}
