import 'package:flutter/material.dart';

import '../storage/legal_consent_storage.dart';

/// Shows a one-time investment risk acknowledgement before trading/investment features.
Future<bool> ensureInvestmentRiskAcknowledged(BuildContext context) async {
  if (await LegalConsentStorage.hasInvestmentRiskAcknowledged()) {
    return true;
  }
  if (!context.mounted) return false;

  final acknowledged = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Investment Risk Acknowledgement'),
      content: const Text(
        'I understand that investments and trading involve market risks and that past performance does not guarantee future results.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('I Understand'),
        ),
      ],
    ),
  );

  if (acknowledged == true) {
    await LegalConsentStorage.setInvestmentRiskAcknowledged(true);
    return true;
  }
  return false;
}
