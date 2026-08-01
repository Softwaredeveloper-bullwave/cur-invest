import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/colors.dart';

/// Shared scaffold for KYC steps — clean, broker-style layout (Zerodha / Angel One inspired).
class KycStepScaffold extends StatelessWidget {
  const KycStepScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.stepLabel,
    required this.stepIndex,
    required this.totalSteps,
    required this.body,
    this.icon = Icons.verified_user_outlined,
    this.footer,
    this.showBack = true,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final String stepLabel;
  final int stepIndex;
  final int totalSteps;
  final Widget body;
  final IconData icon;
  final Widget? footer;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = stepIndex / totalSteps;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showBack)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onBack ??
                            () {
                              if (context.canPop()) {
                                context.pop();
                              }
                            },
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        label: const Text('Back'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brandOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: AppColors.brandOrange, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stepLabel,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: AppColors.brandOrange,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.25),
                      color: AppColors.brandOrange,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Step $stepIndex of $totalSteps',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: body),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class KycInfoCard extends StatelessWidget {
  const KycInfoCard({
    super.key,
    required this.title,
    required this.message,
    this.tone = KycInfoTone.neutral,
  });

  final String title;
  final String message;
  final KycInfoTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (tone) {
      KycInfoTone.success => (AppColors.green.withValues(alpha: 0.1), AppColors.green, Icons.check_circle_outline),
      KycInfoTone.warning => (AppColors.brandOrange.withValues(alpha: 0.1), AppColors.brandOrange, Icons.schedule),
      KycInfoTone.error => (Colors.red.withValues(alpha: 0.08), Colors.red.shade700, Icons.error_outline),
      KycInfoTone.neutral => (Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.onSurface, Icons.info_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: fg.withValues(alpha: 0.9), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum KycInfoTone { neutral, success, warning, error }
