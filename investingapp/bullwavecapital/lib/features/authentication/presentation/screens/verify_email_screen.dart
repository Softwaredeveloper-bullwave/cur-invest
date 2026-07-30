import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _emailController = TextEditingController(
      text: auth.pendingEmail.isNotEmpty ? auth.pendingEmail : (auth.user?.email ?? ''),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final sent = await auth.sendEmailOtp(_emailController.text.trim());
    if (!mounted) return;

    if (sent) {
      context.go(AppRoutes.verifyEmailOtp);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(auth.error ?? 'Could not send verification code.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.red,
      ),
    );
  }

  String _maskedPhone(String phone) {
    if (phone.length != 10) return phone;
    return '${phone.substring(0, 5)} ${phone.substring(5)}';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final phone = auth.phoneNumber.isNotEmpty
        ? auth.phoneNumber
        : (auth.user?.phone ?? '');

    return PremiumAuthShell(
      glowPrimary: const Color(0xFF6366F1),
      glowSecondary: const Color(0xFF818CF8),
      topBar: const PremiumBrandHeader(),
      bottomBar: PremiumAuthBottomBar(
        backEnabled: !auth.isLoading,
        onBack: () => context.go(AppRoutes.otp),
        onNext: _continue,
        isLoading: auth.isLoading,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            const Spacer(),
            PremiumAuthHero(
              pill: 'Step 2 · Email',
              headline: 'VERIFY\nEMAIL',
              body:
                  'Enter your email address. We\'ll send a secure 6-digit code to confirm it\'s yours.',
              showLogo: false,
              belowBody: Column(
                children: [
                  if (phone.isNotEmpty)
                    PremiumAuthStatusChip(
                      icon: Icons.phone_android_rounded,
                      label: 'Phone verified',
                      value: '+91 ${_maskedPhone(phone)}',
                      accent: AppColors.greenSoft,
                    ),
                  if (phone.isNotEmpty) const SizedBox(height: 16),
                  if (AppEnv.showDevOtpHints && auth.emailOtpIsConsoleMode)
                    PremiumAuthDevBanner(
                      message:
                          'SMTP not configured — the verification code will appear on the next screen.',
                    ),
                  PremiumAuthInputField(
                    controller: _emailController,
                    label: 'Email address',
                    hint: 'you@email.com',
                    prefixIcon: Icons.alternate_email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final email = (value ?? '').trim();
                      if (email.isEmpty) return 'Enter your email address';
                      if (!email.contains('@') || !email.contains('.')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
              child: Text(
                'We never share your email with third parties.',
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
      ),
    );
  }
}
