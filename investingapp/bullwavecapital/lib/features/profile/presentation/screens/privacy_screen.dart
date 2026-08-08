import 'package:flutter/material.dart';

import '../../../../core/constants/cbw_privacy_content.dart';
import '../../../../core/constants/legal_config.dart';
import '../../../../core/widgets/legal_document_screen.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LegalDocumentScreen(
      title: 'Privacy Policy',
      subtitle: LegalConfig.appDisplayName,
      intro: cbwPrivacyIntro,
      sections: cbwPrivacySections,
      showTermsLink: true,
    );
  }
}
