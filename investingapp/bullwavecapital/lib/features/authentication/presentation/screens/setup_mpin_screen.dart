import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/security/app_lock_provider.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

/// Create a 4-digit MPIN after phone OTP (optional on first sign-in).
class SetupMpinScreen extends StatefulWidget {
  const SetupMpinScreen({super.key, this.optional = false, this.returnToSettings = false});

  final bool optional;
  final bool returnToSettings;

  @override
  State<SetupMpinScreen> createState() => _SetupMpinScreenState();
}

class _SetupMpinScreenState extends State<SetupMpinScreen> {
  final GlobalKey<PinInputState> _pinKey = GlobalKey<PinInputState>();
  String? _firstPin;
  bool _confirmStep = false;
  bool _enableBiometric = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppLockProvider>().refreshBiometricAvailability();
      if (!mounted) return;
      final available = context.read<AppLockProvider>().biometricAvailable;
      setState(() => _enableBiometric = available);
    });
  }

  Future<void> _onPinEntered(String pin) async {
    if (!_confirmStep) {
      setState(() {
        _firstPin = pin;
        _confirmStep = true;
      });
      _pinKey.currentState?.clear();
      return;
    }

    if (_firstPin != pin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MPINs do not match. Try again.'),
          backgroundColor: AppColors.red,
        ),
      );
      setState(() {
        _firstPin = null;
        _confirmStep = false;
      });
      _pinKey.currentState?.clear();
      return;
    }

    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id;
    if (userId == null || userId.isEmpty) {
      _finishWithoutMpin();
      return;
    }

    setState(() => _isSaving = true);
    final lock = context.read<AppLockProvider>();
    final ok = await lock.setupMpin(
      pin: pin,
      userId: userId,
      enableBiometric: _enableBiometric,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(lock.error ?? 'Could not save MPIN.'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    _finishWithoutMpin();
  }

  void _finishWithoutMpin() {
    context.read<AppLockProvider>().markUnlocked();
    if (widget.returnToSettings) {
      context.pop();
      return;
    }
    final kyc = context.read<KycFlowProvider>();
    context.go(OnboardingFlowNavigator.routeForReturningUser(kyc));
  }

  void _skip() {
    context.read<AppLockProvider>().markUnlocked();
    _finishWithoutMpin();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    final canUseBiometric = lock.biometricAvailable;

    return PremiumAuthShell(
      topBar: widget.optional
          ? Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSaving ? null : _skip,
                child: const Text('Skip for now'),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            _confirmStep ? 'Confirm your MPIN' : 'Create a 4-digit MPIN',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _confirmStep
                ? 'Enter the same MPIN again'
                : 'Quick unlock on this device. Phone OTP is still required on new devices.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onBrandPrimaryMuted,
            ),
          ),
          const SizedBox(height: 32),
          PinInput(
            key: _pinKey,
            enabled: !_isSaving,
            onCompleted: _onPinEntered,
          ),
          if (!_confirmStep && canUseBiometric) ...[
            const SizedBox(height: 24),
            SwitchListTile(
              value: _enableBiometric,
              onChanged: _isSaving
                  ? null
                  : (value) => setState(() => _enableBiometric = value),
              title: Text(
                'Enable ${lock.biometricLabel}',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Use biometrics instead of MPIN when available',
                style: TextStyle(color: AppColors.onBrandPrimaryMuted),
              ),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}
