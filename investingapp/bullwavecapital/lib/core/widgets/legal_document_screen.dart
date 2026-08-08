import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/dimensions.dart';
import '../constants/legal_config.dart';
import '../constants/legal_document_models.dart';
import '../constants/routes.dart';
import '../theme/colors.dart';
import 'custom_app_bar.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.intro,
    required this.sections,
    this.showPrivacyLink = false,
    this.showTermsLink = false,
  });

  final String title;
  final String subtitle;
  final List<String> intro;
  final List<LegalSection> sections;
  final bool showPrivacyLink;
  final bool showTermsLink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.65);
    final headingStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 0.2,
    );

    return Scaffold(
      appBar: CustomAppBar(title: title),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMd,
            AppDimensions.paddingSm,
            AppDimensions.paddingMd,
            AppDimensions.paddingXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Text('Effective Date: ${LegalConfig.effectiveDate}', style: bodyStyle),
              Text('Last Updated: ${LegalConfig.lastUpdated}', style: bodyStyle),
              if (showPrivacyLink || showTermsLink) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (showPrivacyLink)
                      _InlineDocLink(
                        label: 'Privacy Policy',
                        onTap: () => context.push(AppRoutes.privacy),
                      ),
                    if (showTermsLink)
                      _InlineDocLink(
                        label: 'Terms & Conditions',
                        onTap: () => context.push(AppRoutes.terms),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              ...intro.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(p, style: bodyStyle),
                ),
              ),
              ...sections.expand((section) => [
                    const SizedBox(height: 20),
                    Text('${section.number}. ${section.title}', style: headingStyle),
                    const SizedBox(height: 8),
                    ...section.blocks.expand((block) => [
                          ...block.paragraphs.map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(p, style: bodyStyle),
                            ),
                          ),
                          if (block.bullets != null) ...[
                            ...block.bullets!.map(
                              (b) => Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('• ', style: bodyStyle),
                                    Expanded(child: Text(b, style: bodyStyle)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ]),
                  ]),
              const SizedBox(height: 24),
              Text(
                'For questions, contact ${LegalConfig.supportEmail}. '
                'Account deletion: ${LegalConfig.accountDeletionUrl}',
                style: bodyStyle?.copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineDocLink extends StatelessWidget {
  const _InlineDocLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        style: GoogleFonts.inter(
          color: AppColors.brandCyan,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = onTap,
      ),
    );
  }
}
