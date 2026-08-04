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
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final _PendingActionState state;
  final double? progress;

  const _PendingActionItem({
    required this.title,
    required this.subtitle,
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
        subtitle = 'Verify your email to secure your account';
      } else if (auth.needsProfileSetup) {
        subtitle = 'Add your name and photo to finish setup';
      } else if (user != null && user.name.trim().isEmpty) {
        subtitle = 'Add your name to personalise your account';
      } else {
        subtitle = 'A few details left — takes under 2 minutes';
      }

      items.add(
        _PendingActionItem(
          title: 'Complete your profile',
          subtitle: subtitle,
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
                : 'Please resubmit your documents',
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
            subtitle: 'We\'ll notify you once verification is complete',
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
            subtitle: 'Required to invest, add funds, and trade',
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
                : 'Submit income or portfolio proof to retry',
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
            subtitle: 'Your documents are being reviewed by our team',
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
            subtitle: 'Trade index & stock options after quick verification',
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

    final p = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Complete your setup',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                  color: p.textDark,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: HomeThemeA.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: HomeThemeA.primary.withValues(alpha: 0.35)),
                ),
                child: Text(
                  '${items.length}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: HomeThemeA.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PendingActionCard(item: item),
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

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isReview = item.state == _PendingActionState.inReview;
    final isRejected = item.state == _PendingActionState.rejected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: p.card,
            border: Border.all(
              color: item.accent.withValues(alpha: isRejected ? 0.45 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: item.accent.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: item.accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(18),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: item.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(item.icon, color: item.accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: p.textDark,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 3),
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
                              if (item.progress != null &&
                                  item.state == _PendingActionState.actionRequired) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: LinearProgressIndicator(
                                    value: item.progress,
                                    minHeight: 4,
                                    backgroundColor: item.accent.withValues(alpha: 0.12),
                                    color: item.accent,
                                  ),
                                ),
                              ],
                              if (isReview) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'In review',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: item.accent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          isReview
                              ? PhosphorIcons.clock
                              : PhosphorIcons.caretRight,
                          size: isReview ? 18 : 16,
                          color: isRejected
                              ? AppColors.red
                              : p.textMuted.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
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
