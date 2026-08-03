import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/auth_flow_navigation.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/otp_box.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class VerifyEmailOtpScreen extends StatefulWidget {
  const VerifyEmailOtpScreen({super.key});

  @override
  State<VerifyEmailOtpScreen> createState() => _VerifyEmailOtpScreenState();
}

class _VerifyEmailOtpScreenState extends State<VerifyEmailOtpScreen> {
  final GlobalKey<ModernOtpInputState> _otpKey = GlobalKey<ModernOtpInputState>();
  int _secondsRemaining = 30;
  Timer? _timer;
  bool _isResending = false;
  bool _isVerifying = false;
  String _otp = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 30);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final auth = context.read<AuthProvider>();
    final code = _otp.replaceAll(RegExp(r'\D'), '');
    if (code.length != 6 || auth.isLoading) return;

    setState(() => _isVerifying = true);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.verifyEmailOtp(code);
    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (success) {
      await AuthFlowNavigation.afterEmailOtp(context);
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(auth.error ?? 'Incorrect verification code.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.red,
      ),
    );
    _otpKey.currentState?.clear();
    setState(() => _otp = '');
  }

  Future<void> _resendOtp() async {
    if (_secondsRemaining > 0 || _isResending) return;

    final auth = context.read<AuthProvider>();
    if (auth.pendingEmail.isEmpty) {
      if (mounted) context.go(AppRoutes.verifyEmail);
      return;
    }

    setState(() => _isResending = true);
    final sent = await auth.sendEmailOtp(auth.pendingEmail);
    if (!mounted) return;

    setState(() => _isResending = false);

    if (sent) {
      _otpKey.currentState?.clear();
      setState(() => _otp = '');
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode && auth.devOtp != null
                ? 'Dev mode — new code: ${auth.devOtp}'
                : 'Verification code sent to ${auth.pendingEmail}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canResend = _secondsRemaining == 0 && !_isResending;
    final isBusy = auth.isLoading || _isVerifying;
    final canVerify = _otp.replaceAll(RegExp(r'\D'), '').length == 6 && !isBusy;
    final email = auth.pendingEmail;

    return PremiumAuthShell(
      glowPrimary: const Color(0xFF6366F1),
      glowSecondary: const Color(0xFF22D3EE),
      topBar: const PremiumBrandHeader(),
      bottomBar: PremiumAuthBottomBar(
        backEnabled: !isBusy,
        onBack: () => context.go(AppRoutes.verifyEmail),
        onNext: canVerify ? _verifyOtp : () {},
        isLoading: isBusy,
        nextIcon: Icons.check_rounded,
      ),
      child: Column(
        children: [
          const Spacer(),
          PremiumAuthHero(
            pill: 'Step 2 · Email',
            headline: 'ENTER\nCODE',
            body: email.isEmpty
                ? 'Enter the 6-digit verification code sent to your email.'
                : 'Enter the 6-digit code we sent to your inbox.',
            showLogo: false,
            belowBody: Column(
              children: [
                if (email.isNotEmpty) ...[
                  PremiumAuthEmailTarget(email: email),
                  const SizedBox(height: 16),
                ],
                if (AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode)
                  PremiumAuthDevBanner(
                    message: 'SMTP not configured — email OTP is shown below for testing only.',
                  ),
                if (AppEnv.showDevOtpHints && auth.devOtp != null)
                  PremiumAuthDevOtpBadge(otp: auth.devOtp!),
                PremiumGlassField(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: ModernOtpInput(
                    key: _otpKey,
                    enabled: !isBusy,
                    onChanged: (value) => setState(() => _otp = value),
                    onCompleted: (_) {
                      if (!_isVerifying && !auth.isLoading) _verifyOtp();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                PremiumAuthResendAction(
                  canResend: canResend,
                  isResending: _isResending,
                  secondsRemaining: _secondsRemaining,
                  onResend: _resendOtp,
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
              child: Text(
                'Check spam if you don\'t see the email within a minute.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
