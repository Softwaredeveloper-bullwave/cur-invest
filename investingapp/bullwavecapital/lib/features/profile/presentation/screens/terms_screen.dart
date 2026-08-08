import 'package:flutter/material.dart';

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
      intro: cbwTermsIntro,
      sections: cbwTermsSections,
      showPrivacyLink: true,
    );
  }
}
