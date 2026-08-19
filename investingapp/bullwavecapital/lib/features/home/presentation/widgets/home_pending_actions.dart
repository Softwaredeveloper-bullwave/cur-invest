import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/routes.dart';
import '../../../../core/navigation/onboarding_flow_navigator.dart';
import '../../../../core/theme/colors.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../fno/presentation/provider/fno_flow_provider.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';
import 'home_theme_a.dart';

enum _PendingActionState { actionRequired, inReview, rejected }

class _PendingActionItem {
  final String title;
  final String subtitle;
  final String actionLabel;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final _PendingActionState state;
  final double? progress;

  const _PendingActionItem({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.icon,
    required this.accent,
    required this.onTap,
    required this.state,
    this.progress,
  });
}

/// Lemon-style actionable cards for incomplete profile, KYC, and F&O setup.
class HomePendingActionsSection extends StatelessWidget {
  const HomePendingActionsSection({super.key});

  static List<_PendingActionItem> _buildItems(
    BuildContext context,
    AuthProvider auth,
    KycFlowProvider kyc,
    FnoFlowProvider fno,
  ) {
    final items = <_PendingActionItem>[];

    final profileRoute = OnboardingFlowNavigator.profileCompletionRoute(auth);
    if (profileRoute != null) {
      final user = auth.user;
      String subtitle;
      if (auth.needsEmailVerification) {
        subtitle = 'Verify your email to secure your account and unlock all features.';
      } else if (auth.needsProfileSetup) {
        subtitle = 'Add your name and photo — it only takes a minute to finish.';
      } else if (user != null && user.name.trim().isEmpty) {
        subtitle = 'Add your name to personalise your BullWave experience.';
      } else {
        subtitle = 'A few details left — complete setup to start investing.';
      }

      items.add(
        _PendingActionItem(
          title: 'Complete your profile',
          subtitle: subtitle,
          actionLabel: 'Continue setup',
          icon: PhosphorIcons.userCircle,
          accent: AppColors.brandCyan,
          state: _PendingActionState.actionRequired,
          progress: _profileProgress(auth),
          onTap: () => context.push(profileRoute),
        ),
      );
    }

    if (!kyc.isFullyVerified) {
      final pending = kyc.status.identityReviewPending ||
          kyc.status.selfieReviewPending ||
          kyc.status.bankReviewPending ||
          kyc.status.paymentReviewPending ||
          kyc.manualStatus.isPending ||
          (kyc.status.manualFinalApprovalRequired &&
              !kyc.status.finalKycApproved);

      if (kyc.manualStatus.isRejected || kyc.status.overallStatus == 'rejected') {
        items.add(
          _PendingActionItem(
            title: 'KYC verification failed',
            subtitle: kyc.manualStatus.rejectionReason.isNotEmpty
                ? kyc.manualStatus.rejectionReason
                : 'Please resubmit your documents so we can verify your account.',
            actionLabel: 'Resubmit KYC',
            icon: PhosphorIcons.warningCircle,
            accent: AppColors.red,
            state: _PendingActionState.rejected,
            onTap: () => context.push(kyc.verificationRoute),
          ),
        );
      } else if (pending) {
        items.add(
          _PendingActionItem(
            title: 'KYC under review',
            subtitle:
                'Your documents are with our team. We\'ll notify you as soon as verification is complete — usually within 24 hours.',
            actionLabel: 'View status',
            icon: PhosphorIcons.hourglass,
            accent: AppColors.brandOrange,
            state: _PendingActionState.inReview,
            progress: _kycProgress(kyc),
            onTap: () => context.push(AppRoutes.kycPending),
          ),
        );
      } else {
        items.add(
          _PendingActionItem(
            title: 'Complete KYC verification',
            subtitle:
                'Verify your identity to invest in stocks, add funds to your wallet, and start trading.',
            actionLabel: 'Verify now',
            icon: PhosphorIcons.shieldCheck,
            accent: HomeThemeA.primary,
            state: _PendingActionState.actionRequired,
            progress: _kycProgress(kyc),
            onTap: () {
              final next = OnboardingFlowNavigator.nextIncompleteKycStep(kyc);
              context.push(next ?? kyc.verificationRoute);
            },
          ),
        );
      }
    }

    if (kyc.isFullyVerified && !fno.isVerified) {
      if (fno.isRejected) {
        items.add(
          _PendingActionItem(
            title: 'F&O access declined',
            subtitle: fno.status.latestRequest?.rejectionReason?.isNotEmpty == true
                ? fno.status.latestRequest!.rejectionReason!
                : 'Submit income or portfolio proof to unlock futures & options trading.',
            actionLabel: 'Try again',
            icon: PhosphorIcons.chartLineDown,
            accent: AppColors.red,
            state: _PendingActionState.rejected,
            onTap: () => context.push(AppRoutes.fnoVerification),
          ),
        );
      } else if (fno.isPending) {
        items.add(
          _PendingActionItem(
            title: 'F&O verification in progress',
            subtitle:
                'Your F&O documents are being reviewed. You\'ll get access to index & stock options once approved.',
            actionLabel: 'View status',
            icon: PhosphorIcons.chartLineUp,
            accent: AppColors.brandOrange,
            state: _PendingActionState.inReview,
            onTap: () => context.push(AppRoutes.fnoVerification),
          ),
        );
      } else {
        items.add(
          _PendingActionItem(
            title: 'Enable F&O trading',
            subtitle:
                'Trade Nifty, Bank Nifty & stock options. Submit a quick income or portfolio proof to get started.',
            actionLabel: 'Enable F&O',
            icon: PhosphorIcons.chartLineUp,
            accent: AppColors.brandPink,
            state: _PendingActionState.actionRequired,
            onTap: () => context.push(AppRoutes.fnoVerification),
          ),
        );
      }
    }

    return items;
  }

  static double _profileProgress(AuthProvider auth) {
    if (!auth.needsRegistrationFlow) return 1;
    if (auth.needsEmailVerification) return 0.35;
    if (auth.needsProfileSetup) return 0.7;
    return 0.5;
  }

  static double _kycProgress(KycFlowProvider kyc) {
    if (kyc.isFullyVerified) return 1;
    final s = kyc.status;
    var done = 0;
    const total = 4;
    if (s.panVerified) done++;
    if (s.aadhaarVerified) done++;
    if (s.bankVerified || s.bankReviewPending || s.bankDraftReady) done++;
    final identityDone = (!kyc.upiRequired || s.upiVerified || s.paymentReviewPending) &&
        (s.selfieVerified || s.selfieReviewPending);
    if (identityDone) done++;
    return (done / total).clamp(0.0, 0.95);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final kyc = context.watch<KycFlowProvider>();
    final fno = context.watch<FnoFlowProvider>();

    final items = _buildItems(context, auth, kyc, fno);
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SetupSectionHeader(),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingActionCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSectionHeader extends StatelessWidget {
  const _SetupSectionHeader();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            HomeThemeA.primary.withValues(alpha: 0.22),
            HomeThemeA.primary.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(color: HomeThemeA.primary.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: HomeThemeA.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: HomeThemeA.primary.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: HomeThemeA.primary.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              PhosphorIcons.lightning,
              color: HomeThemeA.primaryDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your setup',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    color: p.textDark,
                  ),
                ),
                Text(
                  'Finish these steps to unlock full access',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: p.textGrey,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: HomeThemeA.primary,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: HomeThemeA.primary.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'ACTION',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: HomeThemeA.onPrimary,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingActionCard extends StatelessWidget {
  final _PendingActionItem item;

  const _PendingActionCard({required this.item});

  String get _statusLabel {
    return switch (item.state) {
      _PendingActionState.inReview => 'IN REVIEW',
      _PendingActionState.rejected => 'ACTION NEEDED',
      _PendingActionState.actionRequired => 'PENDING',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isReview = item.state == _PendingActionState.inReview;
    final isRejected = item.state == _PendingActionState.rejected;
    final progress = item.progress;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                item.accent.withValues(alpha: 0.22),
                p.card,
                p.card.withValues(alpha: 0.95),
              ],
            ),
            border: Border.all(
              color: item.accent.withValues(alpha: isRejected ? 0.65 : 0.48),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: item.accent.withValues(alpha: 0.22),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -24,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.accent.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: -16,
                  bottom: -20,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.accent.withValues(alpha: 0.07),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  item.accent.withValues(alpha: 0.35),
                                  item.accent.withValues(alpha: 0.12),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: item.accent.withValues(alpha: 0.45),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: item.accent.withValues(alpha: 0.25),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(item.icon, color: item.accent, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.title,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: -0.35,
                                          color: p.textDark,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                    _StatusPill(
                                      label: _statusLabel,
                                      accent: item.accent,
                                      isReview: isReview,
                                      isRejected: isRejected,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    height: 1.35,
                                    color: p.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (progress != null && isReview) ...[
                            const SizedBox(width: 8),
                            _ProgressRing(
                              progress: progress,
                              accent: item.accent,
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          if (progress != null &&
                              item.state == _PendingActionState.actionRequired) ...[
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(progress * 100).round()}% complete',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: item.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(999),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor:
                                          item.accent.withValues(alpha: 0.15),
                                      color: item.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ] else if (isReview) ...[
                            Icon(
                              PhosphorIcons.clock,
                              size: 14,
                              color: item.accent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Usually verified within 24h',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: item.accent.withValues(alpha: 0.9),
                              ),
                            ),
                            const Spacer(),
                          ] else
                            const Spacer(),
                          _ActionButton(
                            label: item.actionLabel,
                            accent: item.accent,
                            isRejected: isRejected,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isReview;
  final bool isRejected;

  const _StatusPill({
    required this.label,
    required this.accent,
    required this.isReview,
    required this.isRejected,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isRejected
        ? AppColors.red
        : isReview
            ? accent
            : HomeThemeA.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.45),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: isRejected ? Colors.white : HomeThemeA.onPrimary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;
  final Color accent;

  const _ProgressRing({required this.progress, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 4,
            backgroundColor: accent.withValues(alpha: 0.15),
            color: accent,
          ),
          Text(
            '${(progress * 100).round()}%',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color accent;
  final bool isRejected;

  const _ActionButton({
    required this.label,
    required this.accent,
    required this.isRejected,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isRejected ? Colors.white : HomeThemeA.onPrimary;
    final bg = isRejected ? AppColors.red : HomeThemeA.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: bg.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(width: 4),
          Icon(PhosphorIcons.arrowRight, size: 12, color: fg),
        ],
      ),
    );
  }
}
