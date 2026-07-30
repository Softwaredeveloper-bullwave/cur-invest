import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/support_contact.dart';
import '../../../../core/theme/app_theme_extension.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../models/support_model.dart';
import '../widgets/support_contact_sheets.dart';
import '../../../../core/widgets/custom_dialog.dart';
import '../../../profile/presentation/provider/referral_support_provider.dart';

class SupportScreen extends StatefulWidget {
  final String? initialTicketId;

  const SupportScreen({super.key, this.initialTicketId});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  @override
  void initState() {
    super.initState();
    final ticketId = widget.initialTicketId;
    if (ticketId != null && ticketId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialTicket(ticketId));
    }
  }

  Future<void> _openInitialTicket(String ticketId) async {
    final provider = context.read<SupportProvider>();
    if (provider.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    SupportTicketModel? ticket;
    for (final row in provider.tickets) {
      if (row.id == ticketId) {
        ticket = row;
        break;
      }
    }
    ticket ??= await provider.loadTicketDetail(ticketId);
    if (ticket != null && mounted) {
      await _openTicketThread(context, ticket);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportProvider>();
    final colors = context.appColors;

    if (provider.isLoading) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Support'),
        body: Center(
          child: CircularProgressIndicator(color: colors.primary),
        ),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(title: 'Support'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingLg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.brandPrimary, AppColors.brandPrimaryDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.22),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.onBrandPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.headset_mic_rounded,
                      color: AppColors.onBrandPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How can we help?',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.onBrandPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Call or SMS ${SupportContact.displayPhone}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.onBrandPrimaryMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          SupportContact.email,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.onBrandPrimaryMuted,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Row(
              children: [
                Expanded(
                  child: _SupportAction(
                    icon: Icons.sms_outlined,
                    label: 'Message',
                    onTap: () => SupportContactSheets.showSms(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportAction(
                    icon: Icons.phone_outlined,
                    label: 'Call',
                    onTap: () => SupportContactSheets.showCall(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SupportAction(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    onTap: () => SupportContactSheets.showEmail(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.paddingLg),
            Text(
              'FAQ',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingSm),
            ...provider.faqs.map(
              (faq) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(
                    faq.question,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  children: [
                    Text(
                      faq.answer,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.textSecondary,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMd),
            Text(
              'Raise a Ticket',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppDimensions.paddingSm),
            ...provider.tickets.map(
              (ticket) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    ticket.subject,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${ticket.status} · ${ticket.messageCount} message(s)',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                  trailing: _TicketStatusBadge(status: ticket.status),
                  onTap: () => _openTicketThread(context, ticket),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingMd),
            ElevatedButton.icon(
              onPressed: () async {
                final success = await context.read<SupportProvider>().raiseTicket(
                      'General inquiry',
                      message: 'Raised from mobile app',
                    );
                if (context.mounted && success) {
                  AppSnackbar.success(context, 'Ticket raised successfully');
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Raise New Ticket'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openTicketThread(BuildContext context, SupportTicketModel ticket) async {
  final provider = context.read<SupportProvider>();
  final detail = await provider.loadTicketDetail(ticket.id) ?? ticket;
  if (!context.mounted) return;
  final colors = context.appColors;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final messages = detail.messages;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      detail.subject,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  _TicketStatusBadge(status: detail.status),
                ],
              ),
              if (detail.resolutionNote.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    detail.resolutionNote,
                    style: const TextStyle(color: AppColors.greenSoft, height: 1.4),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (messages.isEmpty && detail.message.isNotEmpty)
                      _SupportMessageBubble(
                        author: 'You',
                        body: detail.message,
                        isAdmin: false,
                      ),
                    ...messages.map(
                      (msg) => _SupportMessageBubble(
                        author: msg.authorName.isNotEmpty ? msg.authorName : msg.authorRole,
                        body: msg.body,
                        isAdmin: msg.authorRole == 'admin',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SupportMessageBubble extends StatelessWidget {
  final String author;
  final String body;
  final bool isAdmin;

  const _SupportMessageBubble({
    required this.author,
    required this.body,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.brandPrimary.withValues(alpha: 0.12)
            : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAdmin
              ? AppColors.brandPrimary.withValues(alpha: 0.25)
              : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            author,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isAdmin ? AppColors.brandPrimary : colors.textPrimary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(color: colors.textSecondary, height: 1.45)),
        ],
      ),
    );
  }
}

class _TicketStatusBadge extends StatelessWidget {
  final String status;

  const _TicketStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'Open';
    final fg = isOpen ? AppColors.warning : AppColors.success;
    final bg = isOpen ? AppColors.warning.withValues(alpha: 0.18) : AppColors.success.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SupportAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: colors.primary.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
