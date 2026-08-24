import 'legal_config.dart';
import 'legal_document_models.dart';

const cbwPrivacyIntro = [
  'CBW (Capital Bull Wave) ("CBW", "we", "us", or "our") is committed to protecting the privacy and security of information provided by users of the CBW mobile application, website, and related services (collectively, the "Services").',
  'This Privacy Policy explains what personal and sensitive information we collect, why we collect it, how we use and protect it, when it may be shared, how long we retain it, and the rights and choices available to users.',
  'By using CBW and voluntarily providing information during registration, verification, or use of our Services, you acknowledge that you have read and understood this Privacy Policy.',
];

List<LegalSection> get cbwPrivacySections => <LegalSection>[
  LegalSection(
    number: 1,
    title: 'INFORMATION WE COLLECT',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW collects information necessary to create and verify your account, provide our Services, maintain security, comply with applicable legal requirements, and prevent fraud.',
        ],
      ),
      LegalBlock(
        paragraphs: [
          '1.1 Mobile Number',
          'When you begin registration with CBW, we collect your mobile phone number. Your mobile number may be used for:',
        ],
        bullets: [
          'Creating your CBW account',
          'Sending or delivering verification OTPs',
          'Account authentication and login verification',
          'Fraud prevention',
          'Important service-related communications',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'CBW may use a third-party telecommunications or OTP service provider to deliver or place an OTP verification call.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 2,
    title: 'OTP AND AUTHENTICATION INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may use a one-time password (OTP) delivered through an automated voice call or SMS to verify your mobile number. We may process:',
        ],
        bullets: [
          'Mobile number',
          'OTP verification status',
          'OTP generation and expiry information',
          'Authentication and session information',
          'Security and verification logs',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'OTP information is used for authentication and security purposes. Users should never share an OTP with another person, including CBW personnel.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 3,
    title: 'EMAIL VERIFICATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'After mobile verification, CBW may request your email address. We may collect:',
        ],
        bullets: [
          'Email address',
          'Email verification status and records',
          'Email-related authentication information',
        ],
      ),
      LegalBlock(
        paragraphs: ['Your email address may be used for:'],
        bullets: [
          'Account verification and security',
          'Service communications and account notifications',
          'Customer support',
          'Legal or regulatory communications where required',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 4,
    title: 'PAN VERIFICATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'As part of onboarding, we may collect and process information associated with your Permanent Account Number (PAN), including:',
        ],
        bullets: [
          'PAN number',
          'Name associated with PAN',
          'Date of birth where required',
          'PAN verification status and provider response',
          'Verification reference information',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'PAN information is used for identity verification, onboarding, compliance, fraud prevention, and maintaining accurate records.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 5,
    title: 'AADHAAR AND DIGILOCKER VERIFICATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may provide Aadhaar-related verification through DigiLocker or authorized providers, with your authorization and consent. Depending on the process, CBW may receive:',
        ],
        bullets: [
          'Name, date of birth, and address',
          'Aadhaar-related verification information',
          'Identity/document information and verification status',
          'Information made available through the authorized verification process',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'CBW will only request and process information necessary for the relevant verification purpose.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 6,
    title: 'BANK ACCOUNT VERIFICATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may require bank account verification. Information may include:',
        ],
        bullets: [
          'Account holder name',
          'Bank account number or masked account number',
          'IFSC code and bank name',
          'Verification status and reference IDs',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'CBW will not request your internet banking password, ATM PIN, UPI PIN, or card PIN.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 7,
    title: 'UPI INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may request UPI information where required. This may include:',
        ],
        bullets: [
          'UPI ID/VPA',
          'UPI verification status',
          'Bank/account information returned through verification',
          'Transaction/reference information',
        ],
      ),
      LegalBlock(paragraphs: ['CBW does not require or request your UPI PIN.']),
    ],
  ),
  LegalSection(
    number: 8,
    title: 'SELFIE / PHOTOGRAPH VERIFICATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may require a selfie for identity verification. The selfie may be:',
        ],
        bullets: [
          'Uploaded through the CBW application',
          'Transmitted securely to our backend',
          'Reviewed through authorized verification/admin systems',
          'Compared with permitted identity information where applicable',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Selfie and related verification information may be accessible to authorized CBW personnel through the administrative panel solely for verification, compliance, fraud prevention, and customer support. We do not use selfies for advertising or unrelated purposes.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 9,
    title: 'ADMIN PANEL ACCESS',
    blocks: [
      LegalBlock(
        paragraphs: [
          'Authorized CBW personnel may access information necessary to:',
        ],
        bullets: [
          'Review verification and KYC status',
          'Review submitted verification information and selfies',
          'Review bank/UPI verification status',
          'Resolve verification issues and prevent fraud',
          'Provide customer support and maintain compliance',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Administrative access is restricted through authentication and access-control measures.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 10,
    title: 'DEVICE AND TECHNICAL INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: ['When you use CBW, we may automatically collect:'],
        bullets: [
          'Device type, model, OS version, and application version',
          'IP address and network information',
          'Device identifiers where permitted',
          'Crash, diagnostic, and security logs',
          'Date and time of access',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'This information may be used for security, fraud prevention, troubleshooting, performance, and service reliability.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 11,
    title: 'ACCOUNT CREATION AND VERIFICATION FLOW',
    blocks: [
      LegalBlock(
        paragraphs: ['The CBW onboarding process may include:'],
        bullets: [
          'Mobile number and OTP verification',
          'Email verification',
          'PAN verification',
          'Aadhaar/DigiLocker verification',
          'Bank verification',
          'UPI verification',
          'Selfie verification',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'The exact information requested may vary depending on services, verification methods, legal requirements, and user circumstances.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 12,
    title: 'HOW WE USE YOUR INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: ['CBW may use personal information for:'],
        bullets: [
          'Account management and authentication',
          'Identity and KYC verification',
          'Fraud prevention and security',
          'Customer support',
          'Financial/investment-related services where applicable',
          'Legal and regulatory compliance',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 13,
    title: 'FINANCIAL AND INVESTMENT DISCLAIMER',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may provide market information, analytical tools, charts, and investment-related features.',
          'CBW does not guarantee profits, returns, investment performance, or financial outcomes.',
          'Financial markets involve risk, and users may lose money. Past performance does not guarantee future performance.',
          'Users should make investment decisions based on their own assessment and, where appropriate, seek advice from a qualified financial professional.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 14,
    title: 'SHARING OF PERSONAL INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may share information only when reasonably necessary. Information may be processed by:',
        ],
        bullets: [
          'Verification, PAN, identity, DigiLocker, bank, and UPI providers',
          'OTP/voice-call service providers',
          'Cloud hosting and database infrastructure providers',
          'Security, monitoring, and market-data providers where applicable',
          'Legal or regulatory authorities where required by law',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 15,
    title: 'DATA SECURITY',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW takes reasonable technical and organizational measures to protect information, including:',
        ],
        bullets: [
          'Encryption during transmission and secure HTTPS/TLS connections',
          'Authentication controls and role-based administrative access',
          'Security monitoring and access restrictions',
          'Backup and recovery procedures',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'No electronic system or internet transmission can be guaranteed to be completely secure.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 16,
    title: 'DATA RETENTION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW retains personal information only as long as reasonably necessary for:',
        ],
        bullets: [
          'Providing Services and maintaining accounts',
          'Completing verification and preventing fraud',
          'Resolving disputes and maintaining security',
          'Meeting legal, regulatory, and financial record requirements',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Where information is no longer required, CBW will take reasonable steps to delete, anonymize, or securely dispose of it, subject to applicable retention obligations.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 17,
    title: 'ACCOUNT DELETION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'Users may request deletion of their CBW account through in-app options or ${LegalConfig.accountDeletionUrl}.',
          'When a deletion request is processed, CBW will delete or anonymize applicable personal information unless retention is required or permitted by law.',
          'Certain information may be retained for legal compliance, fraud prevention, security, dispute resolution, or financial record-keeping.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 18,
    title: 'USER RIGHTS',
    blocks: [
      LegalBlock(
        paragraphs: ['Depending on applicable law, users may have rights to:'],
        bullets: [
          'Request access to personal information',
          'Request correction of inaccurate information',
          'Request deletion where legally applicable',
          'Withdraw consent where applicable',
          'Raise privacy-related complaints',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Users may exercise applicable rights by contacting CBW using the contact information below.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 19,
    title: 'CONSENT',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may request consent before collecting or processing certain personal or sensitive information.',
          'For identity verification, users may be required to provide authorization through the applicable verification service.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 20,
    title: 'CHILDREN\'S PRIVACY',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW is intended for users who are legally eligible to use the financial and investment-related services provided by the application.',
          'CBW does not knowingly collect personal information from children in violation of applicable laws.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 21,
    title: 'THIRD-PARTY SERVICES',
    blocks: [
      LegalBlock(
        paragraphs: ['CBW may use third-party services for:'],
        bullets: [
          'Voice OTP and email verification',
          'PAN, identity, DigiLocker, bank, UPI, and selfie verification',
          'Cloud hosting, security, analytics, and market data',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Third-party providers may process information according to their own privacy policies and applicable laws.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 22,
    title: 'CHANGES TO THIS PRIVACY POLICY',
    blocks: [
      LegalBlock(
        paragraphs: [
          'CBW may update this Privacy Policy from time to time. The "Last Updated" date will be updated.',
          'Where required by applicable law, CBW may provide additional notice or obtain consent for material changes.',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 23,
    title: 'CONTACT INFORMATION',
    blocks: [
      LegalBlock(
        paragraphs: [
          'Company: ${LegalConfig.legalCompanyName}',
          'App: ${LegalConfig.appDisplayName}',
          'Privacy Email: ${LegalConfig.privacyEmail}',
          'Support Email: ${LegalConfig.supportEmail}',
          'Phone: ${LegalConfig.supportPhone}',
          'Website: ${LegalConfig.website}',
          'Registered Address: ${LegalConfig.companyAddress}',
          'Account Deletion: ${LegalConfig.accountDeletionUrl}',
          'Grievance/Privacy Contact: ${LegalConfig.grievanceContact}',
          'Grievance Email: ${LegalConfig.grievanceEmail}',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 24,
    title: 'SECURITY NOTICE',
    blocks: [
      LegalBlock(
        paragraphs: ['CBW will never ask users to provide:'],
        bullets: [
          'OTP to CBW employees',
          'UPI PIN',
          'ATM PIN',
          'Internet banking password',
          'Card PIN',
        ],
      ),
      LegalBlock(
        paragraphs: [
          'Users should never disclose these credentials to anyone.',
        ],
      ),
    ],
  ),
];
