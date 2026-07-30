import json

from django.core.management.base import BaseCommand, CommandError

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, get_user_services, list_services


class Command(BaseCommand):
    help = (
        'List all Eko services and their service_code (from the "Get All Services" API), '
        'or with --enabled, list which services are currently activated for this account '
        '(from the "Get User Services" API). Use this to find the exact service_code for '
        'PPI DigiKhata / Aadhaar verification instead of guessing, then run: '
        'python manage.py activate_eko_service <service_code>'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--enabled',
            action='store_true',
            help='Show services already activated for this user_code instead of the full catalog.',
        )

    def handle(self, *args, **options):
        cfg = eko_settings()
        if not cfg.is_configured:
            raise CommandError(
                'Eko credentials are not configured. Set EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, '
                'EKO_INITIATOR_ID and EKO_BASE_URL in .env first.'
            )

        try:
            rows = get_user_services() if options['enabled'] else list_services()
        except EkoKycError as exc:
            raise CommandError(f'Eko request failed ({exc.code or "error"}): {exc}')

        if not rows:
            self.stdout.write(self.style.WARNING('Eko returned no rows — see the Eko GET log line above for the raw response.'))
            return

        self.stdout.write(json.dumps(rows, indent=2, default=str))
        self.stdout.write(
            self.style.SUCCESS(
                f'\n{len(rows)} service(s) listed. Look for "DigiKhata", "PPI", or "Aadhaar" in the '
                'name/description fields above to find the service_code to activate.'
            )
        )
