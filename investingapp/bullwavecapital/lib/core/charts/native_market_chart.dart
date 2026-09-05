import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/stock_model.dart';
import 'chart_candle_utils.dart';
import 'lightweight_chart.dart';

/// Production-grade native chart — grid, volume, SMA, crosshair (no WebView).
class NativeMarketChart extends StatefulWidget {
  final List<CandleModel> candles;
  final double height;
  final MarketChartType chartType;
  final bool showVolume;
  final bool showSma;
  final bool showEma;
  final bool showBollinger;
  final bool enableZoom;
  final String intervalLabel;
  final double? lastPrice;
  final ValueChanged<CandleModel?>? onCrosshair;

  const NativeMarketChart({
    super.key,
    required this.candles,
    required this.height,
    this.chartType = MarketChartType.candlestick,
    this.showVolume = true,
    this.showSma = false,
    this.showEma = false,
    this.showBollinger = false,
    this.enableZoom = true,
    this.intervalLabel = '1D',
    this.lastPrice,
    this.onCrosshair,
  });

  @override
  State<NativeMarketChart> createState() => _NativeMarketChartState();
}

class _NativeMarketChartState extends State<NativeMarketChart> {
  int? _hoverIndex;
  int _visibleCount = 80;
  int _endIndex = 0;
  double _pinchStartVisible = 80;
  Timer? _liveClock;

  static const _bg = Color(0xFF0B0E11);
  static const _grid = Color(0x14FFFFFF);
  static const _text = Color(0xFF8B949E);
  static const _green = Color(0xFF00C853);
  static const _red = Color(0xFFEF5350);
  static const _sma20 = Color(0xFF38BDF8);
  static const _sma50 = Color(0xFFF59E0B);
  static const _ema = Color(0xFFE879F9);
  static const _bb = Color(0x66FFFFFF);

  List<CandleModel> get _all => applyLiveTick(
        normalizeCandles(widget.candles),
        lastPrice: widget.lastPrice,
        intervalLabel: widget.intervalLabel,
      );

  Duration get _barInterval =>
      inferCandleInterval(_all, label: widget.intervalLabel);

  /// Dart [num.clamp] throws `Invalid argument: 8` when lower > upper
  /// (FX daily series often has fewer than 8 candles).
  int _clampVisible(int desired, int length) {
    if (length <= 0) return 0;
    final lo = math.min(8, length);
    return desired.clamp(lo, length);
  }

  List<CandleModel> get _window {
    final all = _all;
    if (all.length < 2) return all;
    final vis = _clampVisible(_visibleCount, all.length);
    var end = _endIndex;
    if (end <= 0 || end > all.length) end = all.length;
    end = end.clamp(vis, all.length);
    final start = (end - vis).clamp(0, all.length);
    return all.sublist(start, end);
  }

  void _resetWindow() {
    final len = _all.length;
    _endIndex = 0;
    _visibleCount = len == 0 ? 80 : (len < 80 ? len : 80);
  }

  void _ensureLiveClock() {
    final live = widget.lastPrice != null && widget.lastPrice! > 0;
    if (live && _liveClock == null) {
      _liveClock = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!live && _liveClock != null) {
      _liveClock!.cancel();
      _liveClock = null;
    }
  }

  @override
  void initState() {
    super.initState();
    _resetWindow();
    _ensureLiveClock();
  }

  @override
  void didUpdateWidget(covariant NativeMarketChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intervalLabel != widget.intervalLabel) {
      _resetWindow();
    }
    _ensureLiveClock();
  }

  @override
  void dispose() {
    _liveClock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candles = _window;
    if (candles.length < 2) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Chart loading…',
            style: TextStyle(color: _text, fontSize: 13),
          ),
        ),
      );
    }

    final all = _all;
    final barInterval = _barInterval;
    final sma20 = widget.showSma ? smaValues(candles, 20) : null;
    final sma50 = widget.showSma ? smaValues(candles, 50) : null;
    final ema20 = widget.showEma ? emaValues(candles, 20) : null;
    final bb = widget.showBollinger ? bollingerBands(candles) : null;
    final forming = widget.lastPrice != null && widget.lastPrice! > 0;
    final liveEdge = _endIndex <= 0 || _endIndex >= all.length;
    final countdown = forming && liveEdge
        ? formingCountdownLabel(barInterval, alignToBucket(candles.last.time, barInterval))
        : null;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const priceAxisW = 62.0;
          const timeAxisH = 20.0;
          final chartW = constraints.maxWidth - priceAxisW;
          final volH = widget.showVolume ? widget.height * 0.18 : 0.0;
          final mainH = widget.height - timeAxisH - volH;

          return Stack(
            children: [
              Column(
                children: [
                  SizedBox(
                    height: mainH + volH,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) => _setIndexFromX(
                              d.localPosition.dx,
                              chartW,
                              candles.length,
                            ),
                            onScaleStart: (_) {
                              _pinchStartVisible = _visibleCount.toDouble();
                            },
                            onScaleUpdate: (d) {
                              if (widget.enableZoom &&
                                  (d.pointerCount > 1 || (d.scale - 1).abs() > 0.04)) {
                                final allLen = all.length;
                                final next = _clampVisible(
                                  (_pinchStartVisible / d.scale).round(),
                                  allLen,
                                );
                                if (next != _visibleCount) {
                                  setState(() => _visibleCount = next);
                                }
                              } else if (d.pointerCount == 1) {
                                _panBy(d.focalPointDelta.dx, chartW);
                                _setIndexFromX(
                                  d.localFocalPoint.dx,
                                  chartW,
                                  candles.length,
                                );
                              }
                            },
                            onScaleEnd: (_) {
                              setState(() => _hoverIndex = null);
                              widget.onCrosshair?.call(null);
                            },
                            onTapUp: (_) {
                              setState(() => _hoverIndex = null);
                              widget.onCrosshair?.call(null);
                            },
                            child: CustomPaint(
                              painter: _MarketChartPainter(
                                candles: candles,
                                chartType: widget.chartType,
                                showVolume: widget.showVolume,
                                sma20: sma20,
                                sma50: sma50,
                                ema20: ema20,
                                bbUpper: bb?.upper,
                                bbLower: bb?.lower,
                                hoverIndex: _hoverIndex,
                                lastPrice: widget.lastPrice,
                                forming: forming && liveEdge,
                                interval: barInterval,
                                mainHeight: mainH,
                                volumeHeight: volH,
                                panOffset: 0,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: priceAxisW,
                          child: CustomPaint(
                            painter: _PriceAxisPainter(
                              candles: candles,
                              lastPrice: widget.lastPrice,
                              mainHeight: mainH,
                              volumeHeight: volH,
                              showVolume: widget.showVolume,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: timeAxisH,
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomPaint(
                            painter: _TimeAxisPainter(
                              candles: candles,
                              interval: barInterval,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                        const SizedBox(width: 62),
                      ],
                    ),
                  ),
                ],
              ),
              if (countdown != null)
                Positioned(
                  left: 8,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC1E2329),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF1E2329)),
                    ),
                    child: Text(
                      'LIVE  $countdown',
                      style: TextStyle(
                        color: candles.last.isBullish ? _green : _red,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              if (widget.enableZoom && all.length > 8)
                Positioned(
                  right: 66,
                  top: 6,
                  child: Column(
                    children: [
                      _zoomBtn(Icons.add, () => _zoomBy(0.75)),
                      const SizedBox(height: 4),
                      _zoomBtn(Icons.remove, () => _zoomBy(1.35)),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _zoomBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xCC1E2329),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: _text),
        ),
      ),
    );
  }

  void _zoomBy(double scale) {
    final all = _all;
    if (all.length < 8) return;
    setState(() {
      _visibleCount = _clampVisible(
        (_visibleCount * scale).round(),
        all.length,
      );
      if (_endIndex <= 0) _endIndex = all.length;
    });
  }

  void _panBy(double dx, double width) {
    final all = _all;
    if (all.length <= _visibleCount || width <= 0) return;
    final vis = _clampVisible(_visibleCount, all.length);
    final slot = width / vis;
    if (slot <= 0) return;
    final shift = -(dx / slot).round();
    if (shift == 0) return;
    setState(() {
      var end = _endIndex <= 0 ? all.length : _endIndex;
      end = (end + shift).clamp(vis, all.length);
      _endIndex = end;
    });
  }

  void _setIndexFromX(double x, double width, int count) {
    if (count <= 0 || width <= 0) return;
    final candles = _window;
    final slot = width / count;
    final index = (x / slot).floor().clamp(0, count - 1);
    if (_hoverIndex != index) {
      setState(() => _hoverIndex = index);
      widget.onCrosshair?.call(candles[index]);
    }
  }
}

/// Format axis labels for both equities and FX (0.59442 should not show as 0.59).
String _formatAxisPrice(double price) {
  final abs = price.abs();
  if (abs >= 1000) return price.toStringAsFixed(0);
  if (abs >= 100) return price.toStringAsFixed(2);
  if (abs >= 1) return price.toStringAsFixed(4);
  return price.toStringAsFixed(5);
}

class _MarketChartPainter extends CustomPainter {
  final List<CandleModel> candles;
  final MarketChartType chartType;
  final bool showVolume;
  final List<double?>? sma20;
  final List<double?>? sma50;
  final List<double?>? ema20;
  final List<double?>? bbUpper;
  final List<double?>? bbLower;
  final int? hoverIndex;
  final double? lastPrice;
  final bool forming;
  final Duration interval;
  final double mainHeight;
  final double volumeHeight;
  final double panOffset;

  _MarketChartPainter({
    required this.candles,
    required this.chartType,
    required this.showVolume,
    this.sma20,
    this.sma50,
    this.ema20,
    this.bbUpper,
    this.bbLower,
    this.hoverIndex,
    this.lastPrice,
    this.forming = false,
    this.interval = const Duration(minutes: 15),
    required this.mainHeight,
    required this.volumeHeight,
    this.panOffset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _NativeMarketChartState._bg,
    );

    if (candles.isEmpty) return;

    final minLow = candles.map((c) => c.low).reduce(math.min);
    final maxHigh = candles.map((c) => c.high).reduce(math.max);
    var range = maxHigh - minLow;
    if (range <= 0) range = 1;
    final pad = range * 0.06;
    final yMin = minLow - pad;
    final yMax = maxHigh + pad;
    range = yMax - yMin;

    double yMain(double price) =>
        mainHeight - ((price - yMin) / range) * (mainHeight - 8) - 4;

    // Grid
    final gridPaint = Paint()
      ..color = _NativeMarketChartState._grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = 4 + (mainHeight - 8) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final vLines = 6;
    for (var i = 0; i <= vLines; i++) {
      final x = size.width * i / vLines;
      canvas.drawLine(Offset(x, 0), Offset(x, mainHeight), gridPaint);
    }

    final count = candles.length;
    final gap = size.width / count;
    final bodyW = (gap * 0.55).clamp(2.0, 12.0);

    // Volume
    if (showVolume && volumeHeight > 0) {
      final maxVol = candles.map((c) => c.volume).reduce(math.max).toDouble();
      if (maxVol > 0) {
        final volTop = mainHeight + 2;
        for (var i = 0; i < count; i++) {
          final c = candles[i];
          final x = gap * i + gap / 2;
          final h = (c.volume / maxVol) * (volumeHeight - 6);
          final color = c.isBullish
              ? _NativeMarketChartState._green.withValues(alpha: 0.35)
              : _NativeMarketChartState._red.withValues(alpha: 0.35);
          canvas.drawRect(
            Rect.fromLTWH(
              x - bodyW / 2,
              volTop + volumeHeight - h - 2,
              bodyW,
              h,
            ),
            Paint()..color = color,
          );
        }
        canvas.drawLine(
          Offset(0, mainHeight),
          Offset(size.width, mainHeight),
          Paint()..color = const Color(0xFF1E2329),
        );
      }
    }

    // SMA overlays
    void drawSma(List<double?>? values, Color color) {
      if (values == null) return;
      final path = Path();
      var started = false;
      for (var i = 0; i < count; i++) {
        final v = values[i];
        if (v == null) continue;
        final x = gap * i + gap / 2;
        final y = yMain(v);
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }

    drawSma(sma20, _NativeMarketChartState._sma20);
    drawSma(sma50, _NativeMarketChartState._sma50);
    drawSma(ema20, _NativeMarketChartState._ema);
    drawSma(bbUpper, _NativeMarketChartState._bb);
    drawSma(bbLower, _NativeMarketChartState._bb);

    // Main series
    if (chartType == MarketChartType.line ||
        chartType == MarketChartType.area) {
      final path = Path();
      final areaPath = Path();
      for (var i = 0; i < count; i++) {
        final x = gap * i + gap / 2;
        final y = yMain(candles[i].close);
        if (i == 0) {
          path.moveTo(x, y);
          areaPath.moveTo(x, mainHeight);
          areaPath.lineTo(x, y);
        } else {
          path.lineTo(x, y);
          areaPath.lineTo(x, y);
        }
      }
      if (chartType == MarketChartType.area) {
        areaPath.lineTo(gap * (count - 1) + gap / 2, mainHeight);
        areaPath.close();
        canvas.drawPath(
          areaPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _NativeMarketChartState._green.withValues(alpha: 0.25),
                _NativeMarketChartState._green.withValues(alpha: 0.02),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, mainHeight)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _NativeMarketChartState._green
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke,
      );
    } else {
      for (var i = 0; i < count; i++) {
        final c = candles[i];
        final x = gap * i + gap / 2;
        final isFormingBar = forming && i == count - 1;
        final color = c.isBullish
            ? _NativeMarketChartState._green
            : _NativeMarketChartState._red;
        final wickW = isFormingBar ? 1.8 : 1.0;
        final barW = isFormingBar ? (bodyW * 1.08).clamp(2.0, 14.0) : bodyW;

        canvas.drawLine(
          Offset(x, yMain(c.high)),
          Offset(x, yMain(c.low)),
          Paint()
            ..color = color
            ..strokeWidth = wickW,
        );

        final top = yMain(math.max(c.open, c.close));
        final bottom = yMain(math.min(c.open, c.close));
        canvas.drawRect(
          Rect.fromLTRB(
            x - barW / 2,
            top,
            x + barW / 2,
            math.max(bottom, top + (isFormingBar ? 2.5 : 2)),
          ),
          Paint()..color = color,
        );
      }
    }

    // Last price line follows the forming close.
    final lp = lastPrice ?? candles.last.close;
    final lpY = yMain(lp);
    final lpColor = candles.last.isBullish
        ? _NativeMarketChartState._green
        : _NativeMarketChartState._red;
    canvas.drawLine(
      Offset(0, lpY),
      Offset(size.width, lpY),
      Paint()
        ..color = lpColor.withValues(alpha: 0.55)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );

    // Crosshair
    if (hoverIndex != null && hoverIndex! >= 0 && hoverIndex! < count) {
      final x = gap * hoverIndex! + gap / 2;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, mainHeight + volumeHeight),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      final c = candles[hoverIndex!];
      final cy = yMain(c.close);
      canvas.drawLine(
        Offset(0, cy),
        Offset(size.width, cy),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..strokeWidth = 1
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter old) => true;
}

class _PriceAxisPainter extends CustomPainter {
  final List<CandleModel> candles;
  final double? lastPrice;
  final double mainHeight;
  final double volumeHeight;
  final bool showVolume;

  _PriceAxisPainter({
    required this.candles,
    this.lastPrice,
    required this.mainHeight,
    required this.volumeHeight,
    required this.showVolume,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    final minLow = candles.map((c) => c.low).reduce(math.min);
    final maxHigh = candles.map((c) => c.high).reduce(math.max);
    var range = maxHigh - minLow;
    if (range <= 0) range = 1;
    final pad = range * 0.06;
    final yMin = minLow - pad;
    final yMax = maxHigh + pad;
    range = yMax - yMin;

    const style = TextStyle(
      color: _NativeMarketChartState._text,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );
    for (var i = 0; i <= 4; i++) {
      final price = yMax - range * i / 4;
      final y = 4 + (mainHeight - 8) * i / 4;
      _drawText(
        canvas,
        _formatAxisPrice(price),
        Offset(2, y - 6),
        style,
        size.width,
      );
    }

    final lp = lastPrice ?? candles.last.close;
    final lpY = mainHeight - ((lp - yMin) / range) * (mainHeight - 8) - 4;
    final tag = _formatAxisPrice(lp);
    final tp = TextPainter(
      text: TextSpan(
        text: tag,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, lpY - 8, size.width - 2, 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = candles.last.isBullish
            ? _NativeMarketChartState._green
            : _NativeMarketChartState._red,
    );
    tp.paint(canvas, Offset(4, lpY - 7));
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style,
    double maxWidth,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _PriceAxisPainter old) => true;
}

class _TimeAxisPainter extends CustomPainter {
  final List<CandleModel> candles;
  final Duration interval;

  _TimeAxisPainter({required this.candles, required this.interval});

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;
    const style = TextStyle(
      color: _NativeMarketChartState._text,
      fontSize: 9,
      fontWeight: FontWeight.w500,
    );
    final count = candles.length;
    final labels = 4;
    for (var i = 0; i <= labels; i++) {
      final idx = (count - 1) * i ~/ labels;
      final c = candles[idx];
      final x = size.width * i / labels;
      final label = formatChartTime(c.time, interval: interval);
      final tp = TextPainter(
        text: TextSpan(text: label, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TimeAxisPainter old) => true;
}
