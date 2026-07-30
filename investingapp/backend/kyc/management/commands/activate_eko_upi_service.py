from django.core.management.base import BaseCommand, CommandError

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, activate_service

# Common Eko service codes related to UPI. The exact verification SKU may
# differ by partner — confirm in connect.eko.in or via list_eko_services.
UPI_SERVICE_CODES = ('86', '59')


class Command(BaseCommand):
    help = (
        'Try activating Eko UPI-related services (86=VPA UPI Payment, 59=UPI Static QR). '
        'If activation fails with "Please provide the value of the field", contact Eko '
        'Connect support to enable the UPI ID Verification product on your merchant account.'
    )

    def handle(self, *args, **options):
        cfg = eko_settings()
        if not cfg.is_configured:
            raise CommandError(
                'Eko credentials are not configured. Set EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, '
                'EKO_INITIATOR_ID and EKO_BASE_URL in .env first.'
            )

        last_exc: EkoKycError | None = None
        for service_code in UPI_SERVICE_CODES:
            self.stdout.write(
                f'Activating Eko service_code={service_code} for user_code={cfg.user_code} ...'
            )
            try:
                result = activate_service(service_code)
            except EkoKycError as exc:
                last_exc = exc
                self.stdout.write(self.style.WARNING(f'  Failed ({exc.code or "error"}): {exc}'))
                continue

            if result.get('status') == 'already_active':
                self.stdout.write(self.style.SUCCESS(f'Service {service_code} is already active.'))
            else:
                self.stdout.write(self.style.SUCCESS(f'Service {service_code} activation submitted: {result}'))
            return

        if last_exc:
            raise CommandError(
                f'Could not activate any UPI service ({last_exc.code or "error"}): {last_exc}\n'
                'Your Eko account likely needs the UPI ID Verification product enabled manually. '
                'Email cs@eko.co.in with your initiator_id and merchant name.'
            )
