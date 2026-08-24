import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../domain/kyc_models.dart';

class BankManualReviewPendingPanel extends StatelessWidget {
  const BankManualReviewPendingPanel({super.key, required this.status});

  final KycStatusModel status;

  String _formatDue(String? iso) {
    if (iso == null || iso.isEmpty) return 'within 24 hours';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'within 24 hours';
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'by $day/$month, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brandOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.schedule_rounded, color: AppColors.brandOrange),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Final verification in progress',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.bankReviewMessage.isNotEmpty
                ? status.bankReviewMessage
                : 'Your bank details were submitted successfully. Our team will manually verify them — please allow up to 24 hours.',
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'Expected ${_formatDue(status.bankReviewDueAt)}',
            style: TextStyle(
              color: AppColors.brandOrange.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          if (status.bankAccountMasked.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Submitted account: ${status.bankAccountMasked}${status.ifsc.isNotEmpty ? ' · ${status.ifsc}' : ''}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
          if (status.upiVpaMasked.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Submitted UPI: ${status.upiVpaMasked}',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'You will receive a notification when verification is complete. You can close this screen and continue browsing.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class BankManualReviewRejectedPanel extends StatelessWidget {
  const BankManualReviewRejectedPanel({
    super.key,
    required this.message,
    this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: AppColors.red),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bank verification could not be completed',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty
                ? message
                : 'Please try again later with a different bank account.',
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try another bank account'),
            ),
          ],
        ],
      ),
    );
  }
}
