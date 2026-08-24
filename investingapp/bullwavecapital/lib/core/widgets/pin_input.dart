import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/dimensions.dart';
import '../theme/app_theme_extension.dart';
import '../theme/colors.dart';

/// Four-digit MPIN entry — same visual language as OTP boxes.
class PinInput extends StatefulWidget {
  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool obscure;

  const PinInput({
    super.key,
    this.length = 4,
    this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.obscure = true,
  });

  @override
  State<PinInput> createState() => PinInputState();
}

class PinInputState extends State<PinInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String get pin => _controller.text;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void clear() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
    setState(() {});
  }

  void _handleChange(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    if (trimmed != value) {
      _controller.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    }

    setState(() {});
    widget.onChanged?.call(trimmed);

    if (trimmed.length == widget.length) {
      widget.onCompleted?.call(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final code = _controller.text;

    return GestureDetector(
      onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: _handleChange,
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (index) {
              final filled = index < code.length;
              final digit = filled ? code[index] : '';
              final display = widget.obscure && filled ? '•' : digit;
              final active = index == code.length && _focusNode.hasFocus;

              return Container(
                width: 56,
                height: 64,
                margin: EdgeInsets.only(
                  right: index == widget.length - 1 ? 0 : AppDimensions.paddingSm,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? AppColors.brandPrimary
                        : filled
                        ? colors.border
                        : AppColors.borderSubtle,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Text(
                  display,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
