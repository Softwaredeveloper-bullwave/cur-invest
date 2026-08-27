import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Fades and slides a section in the first time it enters the viewport.
///
/// Content already on screen paints immediately. Off-screen sections stay
/// hidden until [visibleFraction] of the widget is visible, then play once.
/// Honors [MediaQuery.disableAnimationsOf].
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 360),
    this.slidePx = 14,
    this.visibleFraction = 0.14,
  });

  final Widget child;
  final Duration duration;
  final double slidePx;
  final double visibleFraction;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  ScrollPosition? _position;
  bool _revealed = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _t = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _check(first: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_onScroll);
      _position = next;
      _position?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() => _check();

  void _reveal({required bool animate}) {
    if (_revealed) return;
    _revealed = true;
    _checked = true;
    if (animate) {
      _controller.forward();
      setState(() {});
    } else {
      _controller.value = 1;
    }
  }

  void _check({bool first = false}) {
    if (!mounted || _revealed) return;

    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal(animate: false);
      return;
    }

    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.height <= 0) {
      if (first) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _check(first: true));
      }
      return;
    }

    final view = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final top = padding.top;
    final bottom = view.height - padding.bottom;
    final origin = box.localToGlobal(Offset.zero);
    final widgetTop = origin.dy;
    final widgetBottom = origin.dy + box.size.height;
    final visible = math.min(widgetBottom, bottom) - math.max(widgetTop, top);
    final fraction = visible <= 0 ? 0.0 : (visible / box.size.height).clamp(0.0, 1.0);

    if (fraction >= widget.visibleFraction) {
      _reveal(animate: !first);
      return;
    }

    if (!_checked) {
      setState(() => _checked = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || (_revealed && _controller.value == 1)) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        return Opacity(
          opacity: _t.value,
          child: Transform.translate(
            offset: Offset(0, widget.slidePx * (1 - _t.value)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class SliverScrollReveal extends StatelessWidget {
  const SliverScrollReveal({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(child: ScrollReveal(child: child));
  }
}
