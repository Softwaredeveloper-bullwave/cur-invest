from django.core.management.base import BaseCommand, CommandError

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, activate_pan_service, activate_service

# Service codes documented by Eko Connect. Bank + DigiLocker are v3 KYC tools —
# Eko usually enables those from connect.eko.in / cs@eko.co.in, not this API.
ACTIVATABLE_KYC_SERVICES = (
    ('4', 'PAN Verification'),
    ('86', 'VPA UPI Payment'),
    ('59', 'UPI Static QR'),
)


class Command(BaseCommand):
    help = (
        'Activate all Eko service_codes that can be turned on via API for KYC billing '
        '(PAN + UPI). Bank penny-drop and DigiLocker must be enabled on your Eko '
        'merchant account separately — contact cs@eko.co.in if wallet history shows only PAN debits.'
    )

    def handle(self, *args, **options):
        cfg = eko_settings()
        if not cfg.is_configured:
            raise CommandError(
                'Eko credentials are not configured. Set EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, '
                'EKO_INITIATOR_ID, EKO_USER_CODE and EKO_BASE_URL in .env first.'
            )

        self.stdout.write(f'Activating KYC services for user_code={cfg.user_code} on {cfg.base_url} ...')

        try:
            pan_result = activate_pan_service()
            if pan_result.get('status') == 'already_active':
                self.stdout.write(self.style.SUCCESS('PAN (4): already active'))
            else:
                self.stdout.write(self.style.SUCCESS(f'PAN (4): {pan_result}'))
        except EkoKycError as exc:
            self.stdout.write(self.style.WARNING(f'PAN (4): {exc}'))

        for service_code, label in ACTIVATABLE_KYC_SERVICES[1:]:
            self.stdout.write(f'Activating {label} (service_code={service_code}) ...')
            try:
                result = activate_service(service_code)
            except EkoKycError as exc:
                self.stdout.write(self.style.WARNING(f'  {label}: {exc}'))
                continue
            if result.get('status') == 'already_active':
                self.stdout.write(self.style.SUCCESS(f'  {label}: already active'))
            else:
                self.stdout.write(self.style.SUCCESS(f'  {label}: {result}'))

        self.stdout.write('')
        if not cfg.org_slug:
            self.stdout.write(
                self.style.WARNING(
                    'EKO_ORG_SLUG is empty — penny-less bank verification is skipped. '
                    'Ask Eko for your org slug (docs example: touras) and set it in .env.'
                )
            )
        self.stdout.write(
            'Bank Verification (penny-drop) and DigiLocker are billed separately when those '
            'API calls succeed. If connect.eko.in History shows only PAN, email cs@eko.co.in '
            f'and request: enable Bank Verification + DigiLocker for initiator_id={cfg.initiator_id}.'
        )
