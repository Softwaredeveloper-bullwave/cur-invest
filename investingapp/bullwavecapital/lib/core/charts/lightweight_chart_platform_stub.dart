import 'package:flutter/material.dart';

import '../../features/stocks/presentation/widgets/candlestick_chart.dart';
import '../../models/stock_model.dart';

class LightweightChartPlatformView extends StatelessWidget {
  final String payloadJson;
  final List<CandleModel> candles;
  final double height;

  const LightweightChartPlatformView({
    super.key,
    required this.payloadJson,
    required this.candles,
    required this.height,
  });

  @override
  Widget build(BuildContext context) =>
      CandlestickChart(candles: candles, height: height);
}
