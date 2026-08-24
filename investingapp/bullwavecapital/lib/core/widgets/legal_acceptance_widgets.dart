import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/routes.dart';
import '../theme/colors.dart';

/// Registration/login checkbox with tappable Terms & Privacy links.
class LegalAcceptanceCheckbox extends StatelessWidget {
  const LegalAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.onToggle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final baseStyle = GoogleFonts.inter(
      fontSize: 13,
      color: Colors.white.withValues(alpha: 0.5),
      height: 1.5,
    );
    final linkStyle = GoogleFonts.inter(
      fontSize: 13,
      color: AppColors.brandCyan,
      fontWeight: FontWeight.w600,
      height: 1.5,
    );

    void openTerms() => context.push(AppRoutes.terms);
    void openPrivacy() => context.push(AppRoutes.privacy);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: enabled ? (v) => onChanged(v ?? false) : null,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            activeColor: AppColors.brandPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: enabled ? onToggle : null,
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()..onTap = openTerms,
                  ),
                  const TextSpan(text: ' and acknowledge the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()..onTap = openPrivacy,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// KYC consent acknowledgement shown before identity verification.
class KycConsentCard extends StatelessWidget {
  const KycConsentCard({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );

    void openPrivacy() => context.push(AppRoutes.privacy);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  children: [
                    const TextSpan(
                      text:
                          'I authorize CBW and its authorized verification partners to process the information required for identity and KYC verification in accordance with the ',
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: linkStyle,
                      recognizer: TapGestureRecognizer()..onTap = openPrivacy,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
