// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../models/stock_model.dart';

class LightweightChartPlatformView extends StatefulWidget {
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
  State<LightweightChartPlatformView> createState() =>
      _LightweightChartPlatformViewState();
}

class _LightweightChartPlatformViewState
    extends State<LightweightChartPlatformView> {
  late final String _viewType;
  late final html.IFrameElement _iframe;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _viewType =
        'bullwave-lightweight-chart-${DateTime.now().microsecondsSinceEpoch}';
    _iframe = html.IFrameElement()
      ..src = 'assets/assets/charts/lightweight_chart.html'
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true
      ..setAttribute('allow', 'fullscreen');
    _iframe.onLoad.listen((_) {
      _sendPayload();
      if (mounted) setState(() => _ready = true);
    });
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _iframe);
  }

  @override
  void didUpdateWidget(covariant LightweightChartPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payloadJson != widget.payloadJson) _sendPayload();
  }

  void _sendPayload() {
    final message =
        '{"source":"bullwave-lightweight-chart","payload":${widget.payloadJson}}';
    _iframe.contentWindow?.postMessage(message, '*');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: HtmlElementView(viewType: _viewType)),
          if (!_ready)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF050503),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
