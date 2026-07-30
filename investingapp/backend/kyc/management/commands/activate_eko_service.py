from django.core.management.base import BaseCommand, CommandError

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, activate_service


class Command(BaseCommand):
    help = (
        'One-time activation of any Eko service by service_code for this account. '
        '"Customer not allowed" / "Customer Not Enrolled" errors on a brand-new Eko '
        'production account almost always mean the specific service was never activated. '
        'Find the code first with: python manage.py list_eko_services'
    )

    def add_arguments(self, parser):
        parser.add_argument('service_code', help='The Eko service_code to activate (e.g. from list_eko_services).')

    def handle(self, *args, **options):
        cfg = eko_settings()
        if not cfg.is_configured:
            raise CommandError(
                'Eko credentials are not configured. Set EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, '
                'EKO_INITIATOR_ID and EKO_BASE_URL in .env first.'
            )

        service_code = options['service_code']
        self.stdout.write(f'Activating Eko service_code={service_code} for initiator_id={cfg.initiator_id} ...')
        try:
            result = activate_service(service_code)
        except EkoKycError as exc:
            raise CommandError(f'Activation failed ({exc.code or "error"}): {exc}')

        if result.get('status') == 'already_active':
            self.stdout.write(self.style.SUCCESS(f'Service {service_code} is already active for this initiator_id.'))
        else:
            self.stdout.write(self.style.SUCCESS(f'Service {service_code} activation submitted: {result}'))
            self.stdout.write(
                'Note: Eko sometimes processes this manually on their side — if calls still '
                'fail with "Customer not allowed" after a few minutes, contact cs@eko.co.in '
                'with your initiator_id and the service_code.'
            )
