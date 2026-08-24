import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../domain/kyc_models.dart';

class BankVerificationResultCard extends StatelessWidget {
  const BankVerificationResultCard({
    super.key,
    required this.status,
    this.showMethod = true,
  });

  final KycStatusModel status;
  final bool showMethod;

  String get _verificationLabel {
    if (status.bankReviewPending) {
      return 'Under manual review (up to 24 hours)';
    }
    if (status.bankReviewRejected) {
      return 'Rejected — try another account';
    }
    switch (status.bankVerificationMethod) {
      case 'manual_review':
        return 'Verified manually';
      case 'penniless':
        return 'Verified (Penny-less)';
      case 'penny_drop':
        return 'Verified (Penny Drop)';
      case 'soft_verify':
        return 'Verified (Dev)';
      default:
        return status.bankVerified ? 'Verified' : 'Failed';
    }
  }

  Color get _statusColor {
    if (status.bankVerified) return AppColors.green;
    if (status.bankReviewPending) return AppColors.brandOrange;
    if (status.bankStatus.toLowerCase() == 'failed' ||
        status.bankReviewRejected) {
      return AppColors.red;
    }
    return Colors.orange;
  }

  String _formatDue(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final holderName = status.nameAtBank.isNotEmpty
        ? status.nameAtBank
        : status.accountHolderName;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _statusColor.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.bankVerified
                    ? Icons.verified_rounded
                    : status.bankReviewPending
                    ? Icons.schedule_rounded
                    : Icons.error_outline_rounded,
                color: _statusColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Bank Verification',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ResultRow(
            'Status',
            _verificationLabel,
            emphasize: true,
            valueColor: _statusColor,
          ),
          if (status.bankReviewMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                status.bankReviewMessage,
                style: TextStyle(color: _statusColor, height: 1.4),
              ),
            ),
          if (status.bankReviewPending && status.bankReviewDueAt != null)
            _ResultRow(
              'Review by',
              _formatDue(status.bankReviewDueAt),
              valueColor: _statusColor,
            ),
          if (holderName.isNotEmpty) _ResultRow('Account Holder', holderName),
          if (status.bankName.isNotEmpty) _ResultRow('Bank', status.bankName),
          if (status.bankBranch.isNotEmpty)
            _ResultRow('Branch', status.bankBranch),
          if (status.ifsc.isNotEmpty) _ResultRow('IFSC', status.ifsc),
          if (status.bankAccountMasked.isNotEmpty)
            _ResultRow('Account', status.bankAccountMasked),
          if (showMethod && status.bankVerificationMethod.isNotEmpty)
            _ResultRow('Method', switch (status.bankVerificationMethod) {
              'manual_review' => 'Manual admin review',
              'penniless' => 'Penny-less',
              'penny_drop' => 'Penny Drop',
              'soft_verify' => 'Dev bypass (invalid)',
              _ => status.bankVerificationMethod,
            }),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(
    this.label,
    this.value, {
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? (emphasize ? AppColors.green : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
