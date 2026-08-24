import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/paper_only_mode.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/routes.dart';
import '../../../../core/constants/shell_layout.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/navigation/shell_navigation.dart';
import '../../../../core/utils/bank_verification_guard.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_card.dart';
import '../../../../core/widgets/page_hero_background.dart';
import '../../../../core/widgets/paper_trading_disclaimer.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/robinhood_card.dart';
import '../../../../core/widgets/icon_badge.dart';
import '../../../../core/widgets/shell_highlight_actions.dart';
import '../../../home/presentation/widgets/home_pending_actions.dart';
import '../provider/wallet_provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SafeArea(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMd),
              child: LoadingList(itemCount: 3),
            ),
          );
        }

        final wallet = provider.wallet;
        final p = context.palette;

        if (PaperOnlyMode.enabled) {
          return RefreshIndicator(
            onRefresh: () => provider.loadData(),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PageHeroBackground(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShellPageHeader(
                            title: 'Practice Wallet',
                            subtitle: 'Virtual funds for paper trading',
                          ),
                          const SizedBox(height: 14),
                          const PaperTradingDisclaimer(),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            decoration: p.heroCardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        PhosphorIcons.flask,
                                        size: 20,
                                        color: p.heroCardFg,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'VIRTUAL',
                                        style: ThemeAType.label(
                                          size: 10,
                                          color: p.primary,
                                        ).copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Practice Balance',
                                  style: ThemeAType.secondary(
                                    size: 13,
                                    color: p.heroCardMuted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  CurrencyFormatter.format(
                                    provider.practiceBalance,
                                  ),
                                  style: ThemeAType.price(
                                    size: 34,
                                    color: p.heroCardFg,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                PrimaryButton(
                                  label: 'Open Paper Trading',
                                  icon: Icons.show_chart_rounded,
                                  compact: true,
                                  onPressed: () => pushOverShell(
                                    context,
                                    AppRoutes.paperTrading,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ShellLayout.contentBottomInset),
                  ],
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.loadData(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeroBackground(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ShellPageHeader(
                          title: 'Wallet',
                          subtitle: 'Manage balance, deposits & withdrawals',
                        ),
                        const SizedBox(height: 14),
                        const HomePendingActionsSection(),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          decoration: p.heroCardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      PhosphorIcons.wallet,
                                      size: 20,
                                      color: p.heroCardFg,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (wallet.balance <= 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: p.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'Add funds to start',
                                        style: ThemeAType.label(
                                          size: 10,
                                          color: p.primary,
                                        ).copyWith(fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Available Balance',
                                style: ThemeAType.secondary(
                                  size: 13,
                                  color: p.heroCardMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyFormatter.format(wallet.balance),
                                style: ThemeAType.price(
                                  size: 34,
                                  color: p.heroCardFg,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Add Money',
                                      icon: Icons.add_rounded,
                                      compact: true,
                                      onPressed: () async {
                                        if (!await ensureBankVerified(context)) {
                                          return;
                                        }
                                        if (context.mounted) {
                                          context.push(AppRoutes.deposit);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: SecondaryButton(
                                      label: 'Withdraw',
                                      icon: Icons.arrow_upward_rounded,
                                      compact: true,
                                      onPressed: () async {
                                        if (!await ensureBankVerified(context))
                                          return;
                                        if (context.mounted)
                                          context.push(AppRoutes.withdraw);
                                      },
                                    ),
                                  ),
                                ],
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
                              icon: PhosphorIcons.plusCircle,
                              label: 'Deposit',
                              color: AppColors.brandPrimary,
                              onTap: () async {
                                if (!await ensureBankVerified(context)) return;
                                if (context.mounted) {
                                  context.push(AppRoutes.deposit);
                                }
                              },
                            ),
                            ShellHighlightAction(
                              icon: PhosphorIcons.arrowUp,
                              label: 'Withdraw',
                              color: AppColors.brandOrange,
                              onTap: () async {
                                if (!await ensureBankVerified(context)) return;
                                if (context.mounted)
                                  context.push(AppRoutes.withdraw);
                              },
                            ),
                            ShellHighlightAction(
                              icon: PhosphorIcons.receipt,
                              label: 'History',
                              color: AppColors.blue,
                              onTap: () => context.push(AppRoutes.transactions),
                            ),
                            ShellHighlightAction(
                              icon: PhosphorIcons.bank,
                              label: 'Bank',
                              color: AppColors.green,
                              onTap: () => context.push(AppRoutes.bankDetails),
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
                        if (wallet.bankName.isNotEmpty) ...[
                          const AppSectionHeader(title: 'Bank Account'),
                          const SizedBox(height: AppDimensions.paddingSm),
                          RobinhoodCard(
                            padding: const EdgeInsets.all(
                              AppDimensions.paddingMd,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.green.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance,
                                    color: AppColors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        wallet.bankName,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      Text(
                                        'A/C ${wallet.accountNumber} • ${wallet.ifsc}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.verified,
                                  color: AppColors.green,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.paddingLg),
                        ],
                        AppSectionHeader(
                          title: 'Transactions',
                          actionLabel: 'View All',
                          onAction: () => context.push(AppRoutes.transactions),
                        ),
                        const SizedBox(height: AppDimensions.paddingSm),
                        if (provider.transactions.isEmpty)
                          RobinhoodCard(
                            padding: const EdgeInsets.all(
                              AppDimensions.paddingMd,
                            ),
                            child: Text(
                              wallet.balance <= 0
                                  ? 'No transactions yet. Add money to get started.'
                                  : 'No transactions yet.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          )
                        else
                          ...provider.transactions.map((txn) {
                            final isCredit = txn.type != 'Withdrawal';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RobinhoodCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${isCredit ? '+' : '-'} ${CurrencyFormatter.format(txn.amount)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: isCredit
                                              ? AppColors.green
                                              : AppColors.red,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            txn.type,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            DateFormatter.display(txn.date),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        txn.status,
                                        style: TextStyle(
                                          color: txn.status == 'Completed'
                                              ? AppColors.green
                                              : AppColors.yellow,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        SizedBox(height: ShellLayout.contentBottomInset),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
