import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../features/stocks/presentation/widgets/candlestick_chart.dart';
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
  WebViewController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant LightweightChartPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.payloadJson != widget.payloadJson) _sendPayload();
  }

  Future<void> _init() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF050503))
        ..addJavaScriptChannel(
          'BullWaveChartBridge',
          onMessageReceived: (message) {
            try {
              final event = jsonDecode(message.message);
              if (!mounted || event is! Map) return;
              if (event['type'] == 'ready') {
                setState(() {
                  _ready = true;
                  _failed = false;
                });
              } else if (event['type'] == 'error') {
                setState(() => _failed = true);
              }
            } catch (_) {
              // Ignore malformed renderer diagnostics; never expose raw JS.
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) => _sendPayload(),
            onWebResourceError: (_) {
              if (mounted) setState(() => _failed = true);
            },
          ),
        );
      _controller = controller;
      if (mounted) setState(() {});
      await controller.loadFlutterAsset('assets/charts/lightweight_chart.html');
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _sendPayload() async {
    final controller = _controller;
    if (controller == null || _failed) return;
    final encodedPayload = jsonEncode(widget.payloadJson);
    try {
      await controller.runJavaScript(
        'window.BullWaveChart && '
        'window.BullWaveChart.setData(JSON.parse($encodedPayload));',
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return CandlestickChart(candles: widget.candles, height: widget.height);
    }
    final controller = _controller;
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          if (controller != null)
            Positioned.fill(child: WebViewWidget(controller: controller)),
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
