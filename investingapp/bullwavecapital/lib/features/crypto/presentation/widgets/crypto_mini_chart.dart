import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';

class CryptoMiniChart extends StatelessWidget {
  const CryptoMiniChart({
    super.key,
    required this.values,
    required this.positive,
    this.width = 64,
    this.height = 32,
    this.lineWidth = 1.5,
  });

  final List<double> values;
  final bool positive;
  final double width;
  final double height;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(width: width, height: height);
    }
    final color = positive ? AppColors.green : AppColors.red;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color, strokeWidth: lineWidth),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.strokeWidth,
  });

  final List<double> values;
  final Color color;
  final double strokeWidth;

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

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
