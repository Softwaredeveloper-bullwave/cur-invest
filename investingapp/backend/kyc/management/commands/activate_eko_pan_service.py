from django.core.management.base import BaseCommand, CommandError

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, activate_pan_service


class Command(BaseCommand):
    help = (
        'One-time activation of the Eko PAN Verification service (service_code=4) '
        'for your organisation on the configured EKO_ENVIRONMENT (uat/production). '
        'Required once before PAN verification calls will succeed on Eko.'
    )

    def handle(self, *args, **options):
        cfg = eko_settings()
        if not cfg.is_configured:
            raise CommandError(
                'Eko credentials are not configured. Set EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, '
                'EKO_INITIATOR_ID and EKO_BASE_URL in .env first.'
            )

        self.stdout.write(f'Activating PAN service for initiator_id={cfg.initiator_id} on {cfg.base_url} ...')
        try:
            result = activate_pan_service()
        except EkoKycError as exc:
            raise CommandError(f'Activation failed ({exc.code or "error"}): {exc}')

        if result.get('status') == 'already_active':
            self.stdout.write(self.style.SUCCESS('PAN service is already active for this initiator_id.'))
        else:
            self.stdout.write(self.style.SUCCESS(f'PAN service activation submitted: {result}'))
            self.stdout.write(
                'Note: Eko sometimes processes this request manually on their side — '
                'if PAN verification still fails with "Customer not allowed" after a few '
                'minutes, contact cs@eko.co.in with your initiator_id.'
            )
