import 'package:flutter/material.dart';

import '../theme/theme_a.dart';

/// Rolling last-N last prices for mini sparklines on live tiles.
class TickTape {
  TickTape({this.maxPoints = 28});

  final int maxPoints;
  final Map<String, List<double>> _points = {};

  void record(String id, double price) {
    if (id.isEmpty || !price.isFinite || price <= 0) return;
    final key = id.toLowerCase();
    final list = List<double>.from(_points[key] ?? const <double>[]);
    if (list.isEmpty || (list.last - price).abs() / price > 1e-9) {
      list.add(price);
      if (list.length > maxPoints) {
        list.removeRange(0, list.length - maxPoints);
      }
      _points[key] = list;
    }
  }

  List<double> of(String id) =>
      List<double>.unmodifiable(_points[id.toLowerCase()] ?? const <double>[]);
}

/// Price that flashes green/red and counts when the quote ticks.
class LiveTickPrice extends StatefulWidget {
  const LiveTickPrice({
    super.key,
    required this.value,
    required this.text,
    required this.style,
    this.textAlign = TextAlign.end,
    this.maxLines = 1,
  });

  final double value;
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final int maxLines;

  @override
  State<LiveTickPrice> createState() => _LiveTickPriceState();
}

class _LiveTickPriceState extends State<LiveTickPrice> {
  int _dir = 0;

  @override
  void didUpdateWidget(covariant LiveTickPrice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value - oldWidget.value).abs() > 1e-12) {
      setState(() {
        _dir = widget.value > oldWidget.value ? 1 : -1;
      });
      Future<void>.delayed(const Duration(milliseconds: 850), () {
        if (mounted && _dir != 0) setState(() => _dir = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final flash = _dir > 0
        ? p.positive
        : _dir < 0
            ? p.negative
            : null;
    final color = flash ?? widget.style.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: flash == null
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: flash?.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 280),
        style: widget.style.copyWith(color: color, fontWeight: FontWeight.w800),
        child: Text(
          widget.text,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Pulsing green dot used next to “Live”.
class LivePulseDot extends StatefulWidget {
  const LivePulseDot({super.key, this.size = 7});

  final double size;

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.palette.positive;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_ctrl),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

class LiveSparkline extends StatelessWidget {
  const LiveSparkline({
    super.key,
    required this.values,
    required this.positive,
    this.width = 56,
    this.height = 28,
  });

  final List<double> values;
  final bool positive;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }
    final color = positive
        ? context.palette.positive
        : context.palette.negative;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _LiveSparkPainter(values: values, color: color),
      ),
    );
  }
}

class _LiveSparkPainter extends CustomPainter {
  _LiveSparkPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LiveSparkPainter old) =>
      old.values != values || old.color != color;
}
