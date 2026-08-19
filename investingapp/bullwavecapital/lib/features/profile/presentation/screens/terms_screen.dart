import 'package:flutter/material.dart';

import '../../../../core/config/paper_only_mode.dart';
import '../../../../core/constants/cbw_terms_content.dart';
import '../../../../core/constants/legal_config.dart';
import '../../../../core/widgets/legal_document_screen.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'Terms & Conditions',
      subtitle: LegalConfig.appDisplayName,
      intro: [
        if (PaperOnlyMode.enabled)
          'SIMULATOR MODE: This build is a market learning and paper trading application only. '
              'No real-money deposits, withdrawals, or live brokerage services are offered. '
              'Capital BullWave is not a SEBI-registered broker.',
        ...cbwTermsIntro,
      ],
      sections: cbwTermsSections,
      showPrivacyLink: true,
    );
  }
}
