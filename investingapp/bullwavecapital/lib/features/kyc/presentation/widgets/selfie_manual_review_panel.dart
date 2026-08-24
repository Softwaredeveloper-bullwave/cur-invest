import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../domain/kyc_models.dart';

class SelfieManualReviewPendingPanel extends StatelessWidget {
  const SelfieManualReviewPendingPanel({super.key, required this.status});

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
                  'Selfie under manual review',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.selfieReviewMessage.isNotEmpty
                ? status.selfieReviewMessage
                : 'Your selfie was submitted successfully. Our compliance team will manually verify it — please allow up to 24 hours.',
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Text(
            'Expected ${_formatDue(status.selfieReviewDueAt)}',
            style: TextStyle(
              color: AppColors.brandOrange.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You will receive a notification once verification is complete. You can close this screen and check back later.',
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

class SelfieManualReviewRejectedPanel extends StatelessWidget {
  const SelfieManualReviewRejectedPanel({
    super.key,
    required this.message,
    this.onRetake,
  });

  final String message;
  final VoidCallback? onRetake;

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
                  'Selfie could not be verified',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.isNotEmpty
                ? message
                : 'Please retake your selfie in good lighting with your face clearly visible.',
            style: const TextStyle(height: 1.45, fontSize: 14),
          ),
          if (onRetake != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetake,
              icon: const Icon(Icons.camera_front_rounded, size: 18),
              label: const Text('Retake selfie'),
            ),
          ],
        ],
      ),
    );
  }
}
