from django.core.management.base import BaseCommand, CommandError

from accounts.otp_utils import normalize_phone
from core.integrations.sms_service import send_2factor_autogen_otp, validate_2factor_config


class Command(BaseCommand):
    help = 'Send a test OTP via 2Factor.in AUTOGEN (live SMS — uses account balance).'

    def add_arguments(self, parser):
        parser.add_argument('phone', help='10-digit Indian mobile number')
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Validate config only; do not send SMS.',
        )

    def handle(self, *args, **options):
        problems = validate_2factor_config()
        if problems:
            raise CommandError('2Factor misconfigured:\n- ' + '\n- '.join(problems))

        phone = normalize_phone(options['phone'])
        if not phone:
            raise CommandError('Enter a valid 10-digit phone number.')

        if options['dry_run']:
            self.stdout.write(self.style.SUCCESS(f'2Factor config OK for +91{phone}'))
            return

        session_id = send_2factor_autogen_otp(phone)
        self.stdout.write(
            self.style.SUCCESS(
                f'2Factor OTP triggered for +91{phone}. Session: {session_id[:8]}…'
            )
        )
