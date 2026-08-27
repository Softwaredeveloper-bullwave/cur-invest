import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../../core/widgets/page_hero_background.dart';
import '../../../../core/widgets/scroll_reveal.dart';
import '../../../../core/widgets/profile_tile.dart';
import '../../../../core/widgets/shell_highlight_actions.dart';
import '../../../authentication/presentation/provider/auth_provider.dart';
import '../../../kyc/presentation/provider/kyc_flow_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final p = context.palette;

    if (user == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }

    final avatarUrl = ApiConfig.resolveMediaUrl(user.avatarUrl);
    final displayName = user.displayName;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeroBackground(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile',
                    style: ThemeAType.heading(size: 28, color: p.textDark),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Account & preferences',
                    style: ThemeAType.secondary(size: 14, color: p.textGrey),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: p.heroCardDecoration(radius: 28),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => context.push(AppRoutes.editProfile),
                          child: Stack(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.transparent,
                                  backgroundImage: avatarUrl.isNotEmpty
                                      ? CachedNetworkImageProvider(avatarUrl)
                                      : null,
                                  child: avatarUrl.isEmpty
                                      ? Icon(
                                          Icons.person_rounded,
                                          size: 40,
                                          color: p.heroCardFg,
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: p.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: p.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          displayName,
                          style: ThemeAType.sectionTitle(
                            color: p.heroCardFg,
                            size: 20,
                          ),
                        ),
                        if (user.city.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.city,
                            style: ThemeAType.secondary(
                              size: 14,
                              color: p.heroCardMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '+91 ${user.phone}',
                          style: ThemeAType.body(size: 15, color: p.heroCardFg),
                        ),
                        if (user.email.isNotEmpty)
                          Text(
                            user.email,
                            style: ThemeAType.secondary(
                              size: 14,
                              color: p.heroCardMuted,
                            ),
                          ),
                        if (user.bio.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            user.bio,
                            textAlign: TextAlign.center,
                            style: ThemeAType.secondary(
                              size: 14,
                              color: p.heroCardMuted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _StatusBadge(label: 'PAN', status: user.panStatus),
                            _StatusBadge(label: 'KYC', status: user.kycStatus),
                          ],
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () => context.push(AppRoutes.editProfile),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.heroCardFg,
                            side: BorderSide(
                              color: p.heroCardFg.withValues(alpha: 0.35),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Profile'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Quick access',
                    style: context
                        .typeLabel(12, p.textMuted)
                        .copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ShellHighlightActionsRow(
                    actions: [
                      ShellHighlightAction(
                        icon: PhosphorIcons.userCircle,
                        label: 'Edit',
                        color: AppColors.brandPrimary,
                        onTap: () => context.push(AppRoutes.editProfile),
                      ),
                      ShellHighlightAction(
                        icon: PhosphorIcons.shieldCheck,
                        label: 'KYC',
                        color: AppColors.green,
                        onTap: () => context.push(AppRoutes.kyc),
                      ),
                      ShellHighlightAction(
                        icon: PhosphorIcons.bank,
                        label: 'Bank',
                        color: AppColors.brandCyan,
                        onTap: () => context.push(AppRoutes.bankDetails),
                      ),
                      ShellHighlightAction(
                        icon: PhosphorIcons.gear,
                        label: 'Settings',
                        color: AppColors.blue,
                        onTap: () => context.push(AppRoutes.settings),
                      ),
                      ShellHighlightAction(
                        icon: PhosphorIcons.headset,
                        label: 'Support',
                        color: AppColors.brandOrange,
                        onTap: () => context.push(AppRoutes.support),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScrollReveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  const AppSectionHeader(title: 'Account'),
                  const SizedBox(height: 10),
                  ProfileTile(
                    icon: Icons.person_outline,
                    title: 'Edit Profile',
                    subtitle: 'Name, photo, email, city',
                    onTap: () => context.push(AppRoutes.editProfile),
                  ),
                  ProfileTile(
                    icon: Icons.candlestick_chart_outlined,
                    title: 'Markets & Stocks',
                    onTap: () => context.go(AppRoutes.invest),
                  ),
                  ProfileTile(
                    icon: Icons.star_rounded,
                    title: 'Watchlist',
                    onTap: () => context.push(AppRoutes.watchlist),
                  ),
                  ProfileTile(
                    icon: Icons.smart_toy_outlined,
                    title: 'Wavy — AI Assistant',
                    onTap: () => context.push(AppRoutes.aiAssistant),
                  ),
                  ProfileTile(
                    icon: Icons.notifications_active_outlined,
                    title: 'Price Alerts',
                    onTap: () => context.push(AppRoutes.priceAlerts),
                  ),
                  ProfileTile(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                  ProfileTile(
                    icon: Icons.account_balance_outlined,
                    title: 'Bank Details',
                    onTap: () => context.push(AppRoutes.bankDetails),
                  ),
                  ProfileTile(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () => context.push(AppRoutes.notifications),
                  ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ScrollReveal(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  const AppSectionHeader(title: 'More'),
                  const SizedBox(height: 10),
                  ProfileTile(
                    icon: Icons.headset_mic_outlined,
                    title: 'Support',
                    onTap: () => context.push(AppRoutes.support),
                  ),
                  ProfileTile(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Referral',
                    onTap: () => context.push(AppRoutes.referral),
                  ),
                  ProfileTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () => context.push(AppRoutes.privacy),
                  ),
                  ProfileTile(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  ProfileTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Complete KYC',
                    subtitle: user.kycStatus,
                    onTap: () => context.push(AppRoutes.kyc),
                  ),
                  ProfileTile(
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    iconColor: AppColors.error,
                    onTap: () async {
                      final confirm = await CustomDialog.showConfirm(
                        context,
                        title: 'Logout',
                        message: 'Are you sure you want to logout?',
                        confirmLabel: 'Logout',
                      );
                      if (confirm == true && context.mounted) {
                        context.read<KycFlowProvider>().reset();
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) context.go(AppRoutes.login);
                      }
                    },
                  ),
                      ],
                    ),
                  ),
                  SizedBox(height: ShellLayout.contentBottomInset),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;

  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final verified =
        normalized.contains('verified') || normalized.contains('complete');
    final pending =
        normalized.contains('pending') ||
        normalized.contains('review') ||
        normalized.contains('progress');
    final color = verified
        ? AppColors.greenSoft
        : pending
        ? AppColors.brandGold
        : AppColors.red;

    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label: $status',
              style: context.typeLabel(13, color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
