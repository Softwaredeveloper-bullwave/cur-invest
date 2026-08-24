import 'package:flutter/material.dart';

import '../../../../core/theme/app_decorations.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';

class ScalperOrderConfig {
  const ScalperOrderConfig({
    this.enabled = false,
    this.orderType = 'market',
    this.limitPrice,
    this.stopLoss,
    this.targetPrice,
    this.trailingStopPercent,
  });

  final bool enabled;
  final String orderType;
  final double? limitPrice;
  final double? stopLoss;
  final double? targetPrice;
  final double? trailingStopPercent;

  bool get hasRiskControls =>
      stopLoss != null || targetPrice != null || trailingStopPercent != null;
}

class ScalperControls extends StatefulWidget {
  const ScalperControls({
    super.key,
    required this.referencePrice,
    required this.onChanged,
  });

  final double referencePrice;
  final ValueChanged<ScalperOrderConfig> onChanged;

  @override
  State<ScalperControls> createState() => _ScalperControlsState();
}

class _ScalperControlsState extends State<ScalperControls> {
  bool _enabled = false;
  String _orderType = 'market';
  final _limit = TextEditingController();
  final _stop = TextEditingController();
  final _target = TextEditingController();
  final _trailing = TextEditingController();

  @override
  void dispose() {
    _limit.dispose();
    _stop.dispose();
    _target.dispose();
    _trailing.dispose();
    super.dispose();
  }

  double? _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    return value != null && value > 0 ? value : null;
  }

  void _emit() {
    widget.onChanged(
      ScalperOrderConfig(
        enabled: _enabled,
        orderType: _orderType,
        limitPrice: _number(_limit),
        stopLoss: _number(_stop),
        targetPrice: _number(_target),
        trailingStopPercent: _number(_trailing),
      ),
    );
  }

  void _toggle(bool value) {
    setState(() => _enabled = value);
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: AppColors.brandOrange,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Scalper Mode',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Fast entry with automatic risk exits',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(value: _enabled, onChanged: _toggle),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'market', label: Text('Market')),
                ButtonSegment(value: 'limit', label: Text('Limit')),
              ],
              selected: {_orderType},
              onSelectionChanged: (value) {
                setState(() => _orderType = value.first);
                _emit();
              },
            ),
            if (_orderType == 'limit') ...[
              const SizedBox(height: 12),
              _PriceField(
                controller: _limit,
                label: 'Limit price',
                hint: widget.referencePrice.toStringAsFixed(2),
                onChanged: _emit,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PriceField(
                    controller: _stop,
                    label: 'Stop-loss',
                    hint: (widget.referencePrice * 0.98).toStringAsFixed(2),
                    onChanged: _emit,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PriceField(
                    controller: _target,
                    label: 'Target',
                    hint: (widget.referencePrice * 1.03).toStringAsFixed(2),
                    onChanged: _emit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _PriceField(
              controller: _trailing,
              label: 'Trailing stop (%)',
              hint: '1.0',
              onChanged: _emit,
            ),
            const SizedBox(height: 8),
            Text(
              'SL and target work as OCO: triggering one closes the position and cancels the other.',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
