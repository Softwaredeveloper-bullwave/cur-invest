import 'legal_config.dart';
import 'legal_document_models.dart';

List<String> get cbwTermsIntro => [
  'These Terms & Conditions ("Terms") govern your access to and use of the CBW (Capital Bull Wave) mobile application, website, and related services (collectively, the "Services") operated by ${LegalConfig.legalCompanyName} ("CBW", "we", "us", or "our").',
  'By registering for, accessing, or using the Services, you agree to be bound by these Terms. If you do not agree, do not use the Services.',
  'CBW provides financial and investment-related information, tools, and features. CBW does not guarantee profits, returns, or investment performance. Investments and trading involve financial risk, and you may lose money.',
];

List<LegalSection> get cbwTermsSections => <LegalSection>[
  LegalSection(
    number: 1,
    title: 'About CBW',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW (Capital Bull Wave) is a mobile application and related digital platform that may provide market information, investment-related tools, account onboarding, identity verification, and related financial features.',
        'CBW is operated by ${LegalConfig.legalCompanyName}. Unless explicitly stated in official CBW communications, CBW does not represent itself as a SEBI-registered broker, investment adviser, portfolio manager, or other regulated entity.',
        'These Terms apply to all users of the Services.',
      ]),
    ],
  ),
  LegalSection(
    number: 2,
    title: 'Eligibility',
    blocks: [
      LegalBlock(
        paragraphs: ['To use CBW, you must:'],
        bullets: [
          'Be at least 18 years of age or the age of majority in your jurisdiction, whichever is higher',
          'Be legally eligible to enter into a binding agreement',
          'Be a resident of India unless otherwise permitted by CBW',
          'Not be prohibited from using the Services under applicable law',
          'Provide accurate and complete registration and verification information',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 3,
    title: 'Account Registration',
    blocks: [
      LegalBlock(paragraphs: [
        'To create a CBW account, you must provide a valid mobile number and complete the registration steps presented in the application.',
        'You agree to provide accurate, current, and complete information during registration and to update such information when it changes.',
        'You are responsible for maintaining the confidentiality of your account credentials and for all activity under your account.',
        'CBW may refuse, suspend, or terminate registration at its discretion where permitted by law.',
      ]),
    ],
  ),
  LegalSection(
    number: 4,
    title: 'Mobile Number and OTP',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW uses your mobile number for account creation, authentication, and security verification.',
        'CBW may deliver one-time passwords (OTPs) through SMS, voice call, or other authorized channels using third-party telecommunications or OTP service providers.',
        'You must not share your OTP with anyone, including persons claiming to represent CBW.',
        'CBW will never ask you to disclose your OTP through unauthorized communication channels.',
      ]),
    ],
  ),
  LegalSection(
    number: 5,
    title: 'Email Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'After mobile verification, CBW may require you to provide and verify an email address.',
        'Your email may be used for account security, service communications, customer support, and important account notifications.',
        'You agree to provide a valid email address that you control and to keep it updated.',
      ]),
    ],
  ),
  LegalSection(
    number: 6,
    title: 'KYC and Identity Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may require Know Your Customer (KYC) and identity verification before enabling certain features.',
        'Verification may include PAN verification, Aadhaar/DigiLocker verification, bank account verification, UPI verification, and selfie verification, as applicable.',
        'By proceeding with KYC, you authorize CBW and its authorized verification partners to process information required for identity verification in accordance with the Privacy Policy.',
        'CBW may use third-party providers for verification services. You agree to cooperate with verification requests and provide authentic documents and information.',
      ]),
    ],
  ),
  LegalSection(
    number: 7,
    title: 'PAN Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may collect and verify your Permanent Account Number (PAN) and associated details for identity verification, compliance, and fraud prevention.',
        'You must provide your own valid PAN and the legal name as printed on your PAN card.',
        'You must not submit another person\'s PAN or falsified PAN information.',
        'PAN verification may be performed through authorized third-party verification providers.',
      ]),
    ],
  ),
  LegalSection(
    number: 8,
    title: 'Aadhaar and DigiLocker Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may offer Aadhaar-related verification through DigiLocker or authorized integration providers, subject to your consent and applicable law.',
        'You authorize CBW to receive verification information made available through the authorized verification process.',
        'You must not submit another person\'s Aadhaar-related information or use unauthorized means to complete verification.',
        'CBW will request only information necessary for the relevant verification purpose.',
      ]),
    ],
  ),
  LegalSection(
    number: 9,
    title: 'Bank Account Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may require verification of your bank account as part of onboarding or certain financial features.',
        'Depending on the verification method, CBW may process account holder name, account number or masked account number, IFSC code, bank name, and verification status.',
        'CBW will never ask for your internet banking password, ATM PIN, card PIN, or similar banking credentials.',
        'You must provide your own bank account information and must not submit another person\'s bank details.',
      ]),
    ],
  ),
  LegalSection(
    number: 10,
    title: 'UPI',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may request UPI information where required for verification or related Services.',
        'This may include UPI ID/VPA, verification status, and reference information returned through the verification process.',
        'CBW does not require or request your UPI PIN.',
        'You must not submit another person\'s UPI information. CBW will never ask for your UPI PIN through unauthorized communication.',
      ]),
    ],
  ),
  LegalSection(
    number: 11,
    title: 'Selfie Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may require a selfie or photograph for identity verification.',
        'Your selfie may be transmitted securely, reviewed through authorized verification systems, and compared with permitted identity information where applicable.',
        'Authorized CBW personnel may review selfie and KYC information through the administrative panel solely for verification, compliance, fraud prevention, and customer support.',
        'You must submit your own selfie and must not use another person\'s photograph.',
      ]),
    ],
  ),
  LegalSection(
    number: 12,
    title: 'Administrative Verification',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW operates an administrative system used by authorized personnel to review verification status and resolve verification issues.',
        'Authorized personnel may access information necessary to review KYC status, verification submissions, bank/UPI verification, selfie verification, and related account records.',
        'Administrative access is restricted through authentication and access-control measures.',
      ]),
    ],
  ),
  LegalSection(
    number: 13,
    title: 'Accuracy of Information',
    blocks: [
      LegalBlock(paragraphs: [
        'You represent that all information you provide to CBW is accurate, complete, current, and authentic.',
        'You agree to promptly update information that becomes inaccurate or incomplete.',
        'Providing false, misleading, or unauthorized information may result in suspension or termination of your account and may violate applicable law.',
      ]),
    ],
  ),
  LegalSection(
    number: 14,
    title: 'Market Data and Information',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may display market data, prices, charts, news, and other financial information from third-party sources.',
        'Market data may be delayed, incomplete, inaccurate, or unavailable due to technical issues, exchange rules, or provider limitations.',
        'CBW does not guarantee the accuracy, timeliness, or completeness of market data or information displayed in the application.',
        'You should independently verify information before making investment decisions.',
      ]),
    ],
  ),
  LegalSection(
    number: 15,
    title: 'Investment Risk',
    blocks: [
      LegalBlock(paragraphs: [
        'Investments and trading in securities, derivatives, commodities, and other financial instruments involve substantial risk.',
        'Market prices can rise or fall, and you may lose part or all of your invested capital.',
        'You are solely responsible for your investment decisions and for assessing whether any feature or information is suitable for your circumstances.',
        'CBW does not provide personalized investment advice unless explicitly stated in a separate written agreement.',
      ]),
    ],
  ),
  LegalSection(
    number: 16,
    title: 'No Guarantee of Returns',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW does not guarantee profits, returns, investment performance, or financial outcomes of any kind.',
        'Past performance does not guarantee future results.',
        'Any examples, illustrations, historical data, or performance references are provided for informational purposes only and are not promises of future performance.',
        'Do not rely on CBW content as a guarantee of profit, risk-free investment, or assured returns.',
      ]),
    ],
  ),
  LegalSection(
    number: 17,
    title: 'Investment Information and Analysis',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may provide research summaries, charts, indicators, screeners, alerts, educational content, or analytical tools.',
        'Such information is general in nature and may not be suitable for all users.',
        'CBW does not warrant that any analysis, signal, forecast, or tool will be accurate or profitable.',
        'You should consult a qualified financial professional where appropriate before making investment decisions.',
      ]),
    ],
  ),
  LegalSection(
    number: 18,
    title: 'Trading and Transactions',
    blocks: [
      LegalBlock(paragraphs: [
        'Where trading or transaction features are available, they may be subject to additional terms, exchange rules, and regulatory requirements.',
        'Orders may be rejected, delayed, or partially executed due to market conditions, system limitations, or compliance checks.',
        'You are responsible for reviewing order details before submission and for monitoring your account activity.',
        'CBW is not responsible for losses arising from your trading decisions, order errors, or market movements.',
      ]),
    ],
  ),
  LegalSection(
    number: 19,
    title: 'Third-Party Services',
    blocks: [
      LegalBlock(
        paragraphs: ['CBW may use third-party providers for:'],
        bullets: [
          'OTP and voice-call delivery',
          'Email verification',
          'PAN verification',
          'DigiLocker and identity verification',
          'Bank account verification',
          'UPI verification',
          'Selfie verification',
          'Cloud hosting and infrastructure',
          'Market data and financial information',
          'Security, monitoring, and analytics',
        ],
      ),
      LegalBlock(paragraphs: [
        'Third-party services are subject to their own terms and privacy practices. CBW is not responsible for third-party services outside its reasonable control.',
      ]),
    ],
  ),
  LegalSection(
    number: 20,
    title: 'Fees and Charges',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may charge fees for certain Services, subscriptions, or transactions as disclosed in the application or applicable fee schedules.',
        'Fees may change from time to time with notice where required by law.',
        'Taxes, brokerage charges, exchange fees, or other third-party costs may apply separately.',
        'You are responsible for reviewing applicable fees before using paid features.',
      ]),
    ],
  ),
  LegalSection(
    number: 21,
    title: 'User Responsibilities',
    blocks: [
      LegalBlock(
        paragraphs: ['You agree to:'],
        bullets: [
          'Use the Services only for lawful purposes',
          'Provide accurate and authentic information',
          'Maintain the security of your account',
          'Comply with applicable laws and regulations',
          'Review investment risks before using financial features',
          'Not misuse verification, trading, or account features',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 22,
    title: 'Account Security',
    blocks: [
      LegalBlock(paragraphs: [
        'You must keep your login credentials, OTPs, and device access secure.',
        'Notify CBW promptly if you suspect unauthorized access to your account.',
        'CBW may implement security measures including device checks, session limits, and verification prompts.',
        'CBW will never ask for your UPI PIN, ATM PIN, card PIN, internet banking password, or OTP through unauthorized channels.',
      ]),
    ],
  ),
  LegalSection(
    number: 23,
    title: 'Prohibited Activities',
    blocks: [
      LegalBlock(
        paragraphs: ['You must not use CBW for:'],
        bullets: [
          'Fraud, money laundering, or unlawful activity',
          'Unauthorized access or identity theft',
          'Submitting another person\'s PAN, Aadhaar-related information, bank information, UPI information, or selfie',
          'Circumventing verification, security, or access controls',
          'Scraping, reverse engineering, or interfering with the Services',
          'Misrepresenting your identity or eligibility',
        ],
      ),
    ],
  ),
  LegalSection(
    number: 24,
    title: 'Intellectual Property',
    blocks: [
      LegalBlock(paragraphs: [
        'The CBW application, branding, software, design, content, and related materials are owned by CBW or its licensors and are protected by intellectual property laws.',
        'You receive a limited, non-exclusive, non-transferable license to use the Services for personal, lawful purposes in accordance with these Terms.',
        'You may not copy, modify, distribute, sell, or create derivative works from CBW content except as permitted by law or with CBW\'s written consent.',
      ]),
    ],
  ),
  LegalSection(
    number: 25,
    title: 'User Content',
    blocks: [
      LegalBlock(paragraphs: [
        'If you submit content such as notes, feedback, or support messages, you grant CBW a license to use such content to operate, improve, and support the Services.',
        'You represent that you have the right to submit such content and that it does not violate third-party rights or applicable law.',
        'CBW may remove content that violates these Terms or applicable law.',
      ]),
    ],
  ),
  LegalSection(
    number: 26,
    title: 'Privacy',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW\'s collection, use, and protection of personal information is described in the Privacy Policy.',
        'By using the Services, you acknowledge the Privacy Policy.',
        'Privacy Policy URL: ${LegalConfig.privacyPolicyUrl}',
        'For privacy-related requests, contact ${LegalConfig.privacyEmail}.',
      ]),
    ],
  ),
  LegalSection(
    number: 27,
    title: 'Account Suspension and Termination',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may suspend or terminate your account if you violate these Terms, provide false information, engage in prohibited activities, or where required by law or risk management policies.',
        'Suspension or termination may limit access to features, verification status, or account data subject to legal retention requirements.',
        'You may stop using the Services at any time, subject to outstanding obligations and applicable retention rules.',
      ]),
    ],
  ),
  LegalSection(
    number: 28,
    title: 'Account Deletion',
    blocks: [
      LegalBlock(paragraphs: [
        'You may request deletion of your CBW account through in-app options or the account deletion mechanism at ${LegalConfig.accountDeletionUrl}.',
        'Upon processing a valid deletion request, CBW will delete or anonymize applicable personal information unless retention is required or permitted by law.',
        'Certain records may be retained for legal compliance, fraud prevention, dispute resolution, security, or financial record-keeping.',
      ]),
    ],
  ),
  LegalSection(
    number: 29,
    title: 'Service Availability',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW strives to maintain reliable Services but does not guarantee uninterrupted or error-free operation.',
        'Services may be unavailable due to maintenance, upgrades, network issues, third-party outages, or force majeure events.',
        'CBW may modify, suspend, or discontinue features with notice where reasonably practicable.',
      ]),
    ],
  ),
  LegalSection(
    number: 30,
    title: 'Limitation of Liability',
    blocks: [
      LegalBlock(paragraphs: [
        'To the maximum extent permitted by law, CBW and its affiliates, officers, employees, and service providers shall not be liable for indirect, incidental, special, consequential, or punitive damages, or for loss of profits, data, or investment losses.',
        'CBW is not liable for market movements, trading losses, delayed or inaccurate market data, third-party service failures, or unauthorized account access resulting from your failure to safeguard credentials.',
        'Where liability cannot be excluded, CBW\'s total liability shall be limited to the amount permitted under applicable law.',
      ]),
    ],
  ),
  LegalSection(
    number: 31,
    title: 'Indemnification',
    blocks: [
      LegalBlock(paragraphs: [
        'You agree to indemnify and hold harmless CBW and its affiliates, officers, employees, and agents from claims, losses, liabilities, and expenses arising from your use of the Services, violation of these Terms, provision of inaccurate information, or infringement of third-party rights.',
      ]),
    ],
  ),
  LegalSection(
    number: 32,
    title: 'Changes to Services',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may add, modify, or remove features, verification methods, or Service components from time to time.',
        'Material changes affecting your rights may be communicated through the application, email, or other reasonable means where required.',
      ]),
    ],
  ),
  LegalSection(
    number: 33,
    title: 'Changes to Terms',
    blocks: [
      LegalBlock(paragraphs: [
        'CBW may update these Terms from time to time. The "Last Updated" date will reflect the latest revision.',
        'Continued use of the Services after updated Terms are posted constitutes acceptance, unless applicable law requires additional consent or notice.',
        'Published Terms URL: ${LegalConfig.termsUrl}',
      ]),
    ],
  ),
  LegalSection(
    number: 34,
    title: 'Governing Law',
    blocks: [
      LegalBlock(paragraphs: [
        'These Terms are governed by the laws of India.',
        'Subject to applicable law, courts in ${LegalConfig.governingCity} shall have jurisdiction over disputes arising from or relating to these Terms or the Services.',
      ]),
    ],
  ),
  LegalSection(
    number: 35,
    title: 'Grievance and Customer Support',
    blocks: [
      LegalBlock(paragraphs: [
        'For support inquiries, contact ${LegalConfig.supportEmail} or ${LegalConfig.supportPhone}.',
        'For privacy-related grievances, contact ${LegalConfig.privacyEmail}.',
        'Grievance Officer: ${LegalConfig.grievanceContact}',
        'Grievance Email: ${LegalConfig.grievanceEmail}',
        'Registered Address: ${LegalConfig.companyAddress}',
        'Website: ${LegalConfig.website}',
      ]),
    ],
  ),
  LegalSection(
    number: 36,
    title: 'Electronic Acceptance',
    blocks: [
      LegalBlock(paragraphs: [
        'By selecting acceptance checkboxes, completing registration, or using the Services, you agree that your electronic acceptance has the same legal effect as a handwritten signature to the extent permitted by applicable law.',
        'CBW may record acceptance status, timestamps, and application version for compliance and audit purposes.',
      ]),
    ],
  ),
  LegalSection(
    number: 37,
    title: 'User Acknowledgement',
    blocks: [
      LegalBlock(
        paragraphs: ['By using CBW, you acknowledge that:'],
        bullets: [
          'CBW does not guarantee profits or returns',
          'Investments and trading involve financial risk',
          'Past performance does not guarantee future results',
          'Market data may be delayed, incomplete, or inaccurate',
          'You are responsible for your own investment decisions',
          'You will provide accurate and authentic verification information',
          'You will not share OTPs, UPI PINs, ATM PINs, card PINs, or banking passwords with anyone',
          'You have read and understood these Terms and the Privacy Policy',
        ],
      ),
    ],
  ),
];
