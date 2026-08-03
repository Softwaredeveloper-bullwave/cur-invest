import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/theme/colors.dart';
import '../../../profile/presentation/provider/app_provider.dart';
import '../provider/auth_provider.dart';
import '../widgets/premium_auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _phoneController = TextEditingController(text: auth.phoneNumber);

    final registered = GoRouterState.of(context).uri.queryParameters['registered'];
    if (registered == '1') {
      auth.beginSignIn();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        auth.setLoginSuccessMessage(
          'Registration complete. Sign in with your mobile number to continue.',
        );
      });
    } else if (!auth.isRegistrationFlow) {
      auth.beginSignIn();
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtpAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    if (!auth.termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to continue.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    auth.clearError();
    auth.setPhoneNumber(_phoneController.text);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.sendOtp();
    if (!mounted) return;

    if (success) {
      auth.setLoginSuccessMessage(null);
      if (AppEnv.showDevOtpHints && auth.otpIsConsoleMode && auth.devOtp != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Dev OTP: ${auth.devOtp}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      router.push(AppRoutes.otp);
    }
  }

  void _startRegistration() {
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();
    auth.beginRegistration();
    auth.clearError();
    auth.setLoginSuccessMessage(null);
    if (app.hasCompletedOnboarding) {
      context.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isRegistrationFlow) {
      return _RegistrationPhoneStep(
        formKey: _formKey,
        phoneController: _phoneController,
        onContinue: _sendOtpAndContinue,
      );
    }
    return _SignInView(
      formKey: _formKey,
      phoneController: _phoneController,
      onSignIn: _sendOtpAndContinue,
      onRegister: _startRegistration,
    );
  }
}

class _SignInView extends StatelessWidget {
  const _SignInView({
    required this.formKey,
    required this.phoneController,
    required this.onSignIn,
    required this.onRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final VoidCallback onSignIn;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return PremiumAuthShell(
      glowPrimary: const Color(0xFF2563EB),
      glowSecondary: const Color(0xFF06B6D4),
      topBar: const PremiumBrandHeader(),
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const SizedBox(height: 24),
            const PremiumPillTag(label: 'Secure sign in'),
            const SizedBox(height: 20),
            const PremiumAuthHeadline(text: 'WELCOME\nBACK'),
            const SizedBox(height: 12),
            PremiumAuthBody(
              text: 'Sign in with the mobile number linked to your BullWave account.',
            ),
            if (auth.loginSuccessMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.green.withValues(alpha: 0.35)),
                ),
                child: Text(
                  auth.loginSuccessMessage!,
                  style: GoogleFonts.inter(
                    color: AppColors.greenSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.red.withValues(alpha: 0.35)),
                ),
                child: Text(
                  auth.error!,
                  style: GoogleFonts.inter(
                    color: AppColors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Mobile number',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            PremiumGlassField(
              child: TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !auth.isLoading,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (value) {
                  if (value == null || value.length != 10) {
                    return 'Enter a valid 10-digit mobile number';
                  }
                  if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                    return 'Enter a valid Indian mobile number';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: '9876543210',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Text(
                      '+91',
                      style: GoogleFonts.inter(
                        color: AppColors.brandCyan,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: auth.termsAccepted,
                    onChanged: auth.isLoading ? null : (v) => auth.setTermsAccepted(v ?? false),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    activeColor: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: auth.isLoading ? null : () => auth.setTermsAccepted(!auth.termsAccepted),
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5),
                          height: 1.5,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(color: AppColors.brandCyan, fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(color: AppColors.brandCyan, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed: auth.isLoading ? null : onSignIn,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  disabledBackgroundColor: AppColors.brandPrimary.withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(
                        'Sign in with OTP',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: TextButton(
                onPressed: auth.isLoading ? null : onRegister,
                child: Text.rich(
                  TextSpan(
                    text: 'New to BullWave? ',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                    ),
                    children: const [
                      TextSpan(
                        text: 'Register',
                        style: TextStyle(
                          color: AppColors.brandCyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your session stays active until you sign out.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Registration step 1 — unchanged phone entry used by the existing registration funnel.
class _RegistrationPhoneStep extends StatelessWidget {
  const _RegistrationPhoneStep({
    required this.formKey,
    required this.phoneController,
    required this.onContinue,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController phoneController;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canGoBackToOnboarding =
        !context.watch<AppProvider>().hasCompletedOnboarding;

    return PremiumAuthShell(
      glowPrimary: const Color(0xFF9333EA),
      glowSecondary: const Color(0xFFEC4899),
      topBar: PremiumBrandHeader(
        trailing: canGoBackToOnboarding
            ? TextButton(
                onPressed: () => context.go(AppRoutes.onboarding),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              )
            : null,
      ),
      bottomBar: PremiumAuthBottomBar(
        showBack: canGoBackToOnboarding,
        backEnabled: canGoBackToOnboarding && !auth.isLoading,
        onBack: canGoBackToOnboarding
            ? () => context.go(AppRoutes.onboarding)
            : () {},
        onNext: onContinue,
        isLoading: auth.isLoading,
      ),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            const Spacer(),
            PremiumAuthHero(
              pill: 'Step 1 · Phone',
              headline: 'CREATE\nACCOUNT',
              body: 'Enter your mobile number. We\'ll send a secure 6-digit OTP to verify you.',
              showLogo: true,
              belowBody: PremiumGlassField(
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (value) {
                    if (value == null || value.length != 10) {
                      return 'Enter a valid 10 digit number';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: '9876543210',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      child: Text(
                        '+91',
                        style: GoogleFonts.inter(
                          color: AppColors.brandCyan,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: auth.termsAccepted,
                      onChanged: (v) => auth.setTermsAccepted(v ?? false),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      activeColor: AppColors.brandPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => auth.setTermsAccepted(!auth.termsAccepted),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.5,
                          ),
                          children: const [
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                color: AppColors.brandCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.brandCyan,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
