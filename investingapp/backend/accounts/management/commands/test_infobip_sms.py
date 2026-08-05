"""Send a test OTP SMS via Infobip — run on EC2 to debug delivery."""

from django.core.management.base import BaseCommand, CommandError

from core.integrations.sms_service import (
    SMSError,
    _infobip_otp_body,
    _send_infobip_message,
    validate_infobip_config,
)
from accounts.otp_utils import normalize_phone


class Command(BaseCommand):
    help = 'Send one test Infobip OTP SMS and print the API response (for debugging +91 delivery).'

    def add_arguments(self, parser):
        parser.add_argument('phone', help='10-digit Indian mobile, e.g. 8700799173')
        parser.add_argument(
            '--otp',
            default='123456',
            help='OTP code to embed in the message (default: 123456)',
        )

    def handle(self, *args, **options):
        phone = normalize_phone(options['phone'])
        if not phone:
            raise CommandError('Enter a valid 10-digit phone number.')

        problems = validate_infobip_config()
        if problems:
            for problem in problems:
                self.stderr.write(self.style.ERROR(problem))
            raise CommandError('Fix Infobip / DLT settings in backend/.env first.')

        body = _infobip_otp_body(options['otp'])
        self.stdout.write(f'Sending test SMS to +91{phone}')
        self.stdout.write(f'Message: {body}')

        try:
            meta = _send_infobip_message(phone, body)
        except SMSError as exc:
            raise CommandError(str(exc)) from exc

        self.stdout.write(self.style.SUCCESS(f"Infobip accepted — messageId={meta.get('messageId')} status={meta.get('status')}"))
        self.stdout.write(
            'If SMS does not arrive, check Infobip portal → SMS logs for this messageId.'
        )
