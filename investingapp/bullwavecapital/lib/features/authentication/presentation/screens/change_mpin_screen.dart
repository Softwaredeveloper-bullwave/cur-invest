import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/security/app_lock_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/pin_input.dart';

class ChangeMpinScreen extends StatefulWidget {
  const ChangeMpinScreen({super.key});

  @override
  State<ChangeMpinScreen> createState() => _ChangeMpinScreenState();
}

class _ChangeMpinScreenState extends State<ChangeMpinScreen> {
  final GlobalKey<PinInputState> _pinKey = GlobalKey<PinInputState>();
  int _step = 0;
  String? _currentPin;
  String? _newPin;
  bool _isSaving = false;

  String get _title {
    switch (_step) {
      case 0:
        return 'Enter current MPIN';
      case 1:
        return 'Enter new MPIN';
      default:
        return 'Confirm new MPIN';
    }
  }

  Future<void> _onPinEntered(String pin) async {
    if (_step == 0) {
      final lock = context.read<AppLockProvider>();
      final ok = await lock.verifyMpin(pin);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lock.error ?? 'Incorrect MPIN.'),
            backgroundColor: AppColors.red,
          ),
        );
        _pinKey.currentState?.clear();
        return;
      }
      lock.markUnlocked();
      setState(() {
        _currentPin = pin;
        _step = 1;
      });
      _pinKey.currentState?.clear();
      return;
    }

    if (_step == 1) {
      setState(() {
        _newPin = pin;
        _step = 2;
      });
      _pinKey.currentState?.clear();
      return;
    }

    if (_newPin != pin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New MPINs do not match.'),
          backgroundColor: AppColors.red,
        ),
      );
      setState(() => _step = 1);
      _pinKey.currentState?.clear();
      return;
    }

    setState(() => _isSaving = true);
    final lock = context.read<AppLockProvider>();
    final ok = await lock.changeMpin(currentPin: _currentPin!, newPin: pin);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lock.error ?? 'Could not change MPIN.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('MPIN updated successfully.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Change MPIN'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              _title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PinInput(
              key: _pinKey,
              enabled: !_isSaving,
              onCompleted: _onPinEntered,
            ),
          ],
        ),
      ),
    );
  }
}
