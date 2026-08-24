import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/pin_input.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import '../provider/auth_provider.dart';
import '../../../../core/security/app_lock_provider.dart';
import '../widgets/premium_auth_ui.dart';

/// Local unlock — MPIN or biometric. Phone OTP remains the account login.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final GlobalKey<PinInputState> _pinKey = GlobalKey<PinInputState>();
  bool _isVerifying = false;
  bool _biometricAttempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareBiometric());
  }

  Future<void> _prepareBiometric() async {
    final lock = context.read<AppLockProvider>();
    await lock.refreshBiometricAvailability();
    if (!mounted) return;
    // Short delay so FlutterFragmentActivity is ready for the system sheet.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    if (_biometricAttempted) return;
    final lock = context.read<AppLockProvider>();
    if (!lock.biometricEnabled || !lock.biometricAvailable) return;
    _biometricAttempted = true;
    final ok = await lock.unlockWithBiometric();
    if (!mounted || !ok) return;
    _goNext();
  }

  Future<void> _verifyPin(String pin) async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    final lock = context.read<AppLockProvider>();
    final ok = await lock.verifyMpin(pin);
    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (lock.shouldForceLogout()) {
      await context.read<AuthProvider>().logout();
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    if (ok) {
      _goNext();
      return;
    }

    _pinKey.currentState?.clear();
  }

  void _goNext() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      context.go(AppRoutes.login);
      return;
    }
    final kyc = context.read<KycFlowProvider>();
    context.go(OnboardingFlowNavigator.routeForReturningUser(kyc));
  }

  Future<void> _unlockWithBiometric() async {
    final lock = context.read<AppLockProvider>();
    await lock.refreshBiometricAvailability();
    if (!lock.biometricAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Biometrics not set up on this phone. Use MPIN or enroll in Settings.',
          ),
        ),
      );
      return;
    }
    final ok = await lock.unlockWithBiometric();
    if (!mounted || !ok) return;
    _goNext();
  }

  @override
  Widget build(BuildContext context) {
    final lock = context.watch<AppLockProvider>();
    final auth = context.watch<AuthProvider>();
    final name = auth.user?.name.trim();
    final greeting = (name != null && name.isNotEmpty)
        ? 'Welcome back, $name'
        : 'Welcome back';
    final biometricLabel = lock.biometricLabel;

    return PremiumAuthShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            greeting,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lock.biometricEnabled && lock.biometricAvailable
                ? 'Use $biometricLabel or enter MPIN'
                : 'Enter your MPIN to continue',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.onBrandPrimaryMuted,
            ),
          ),
          const SizedBox(height: 32),
          PinInput(
            key: _pinKey,
            enabled: !_isVerifying,
            onCompleted: _verifyPin,
          ),
          if (lock.error != null) ...[
            const SizedBox(height: 16),
            Text(
              lock.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red, fontSize: 14),
            ),
          ],
          const SizedBox(height: 24),
          if (lock.biometricEnabled && lock.biometricAvailable)
            OutlinedButton.icon(
              onPressed: _isVerifying ? null : _unlockWithBiometric,
              icon: Icon(
                biometricLabel.contains('Face')
                    ? Icons.face_rounded
                    : Icons.fingerprint_rounded,
              ),
              label: Text('Use $biometricLabel'),
            ),
          const Spacer(),
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) return;
              context.go(AppRoutes.login);
            },
            child: const Text('Forgot MPIN? Sign in with phone'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
