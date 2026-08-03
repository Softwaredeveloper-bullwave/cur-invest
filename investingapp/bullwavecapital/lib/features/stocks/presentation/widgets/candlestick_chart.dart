import 'package:flutter/material.dart';

import '../../../../core/charts/native_market_chart.dart';
import '../../../../models/stock_model.dart';

/// Legacy alias — delegates to [NativeMarketChart].
class CandlestickChart extends StatelessWidget {
  final List<CandleModel> candles;
  final double height;

  const CandlestickChart({super.key, required this.candles, this.height = 220});

  @override
  Widget build(BuildContext context) {
    return NativeMarketChart(
      candles: candles,
      height: height,
      showVolume: true,
    );
  }
}
