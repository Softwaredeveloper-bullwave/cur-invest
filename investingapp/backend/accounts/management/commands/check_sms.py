from django.core.management.base import BaseCommand

from core.integrations.sms_service import (
    is_live_sms,
    local_lan_ip,
    sms_config_status,
    validate_2factor_config,
    validate_infobip_config,
    validate_twilio_config,
)


class Command(BaseCommand):
    help = 'Print SMS OTP configuration and physical-device testing hints.'

    def handle(self, *args, **options):
        status = sms_config_status()
        self.stdout.write(f"Env file: {status['env_file']}")
        self.stdout.write(f"SMS_PROVIDER (explicit)={status['explicit_provider']}")
        self.stdout.write(f"Effective provider={status['provider']}")
        self.stdout.write(f"Mode={status['mode']} ({'live SMS' if status['mode'] == 'sms' else 'dev/console'})")
        self.stdout.write(f"2Factor configured={status.get('twofactor_configured')}")
        self.stdout.write(f"2Factor AUTOGEN={status.get('twofactor_autogen')}")
        self.stdout.write(f"Twilio Verify={status['twilio_verify']}")
        self.stdout.write(f"Infobip configured={status['infobip_configured']}")
        self.stdout.write(f"Infobip DLT configured={status.get('infobip_dlt_configured')}")
        self.stdout.write(f"MSG91 configured={status['msg91_configured']}")
        self.stdout.write(f"Twilio configured={status['twilio_configured']}")

        for problem in status.get('twofactor_problems') or []:
            self.stderr.write(self.style.ERROR(f'  ✗ {problem}'))
        for problem in status.get('infobip_problems') or []:
            self.stderr.write(self.style.ERROR(f'  ✗ {problem}'))
        for problem in status.get('twilio_problems') or []:
            self.stderr.write(self.style.ERROR(f'  ✗ {problem}'))

        for hint in status['hints']:
            self.stdout.write(f'  • {hint}')

        lan = local_lan_ip()
        if lan:
            self.stdout.write('')
            self.stdout.write('Physical phone on same Wi‑Fi:')
            self.stdout.write('  1. python manage.py runserver 0.0.0.0:8000')
            self.stdout.write(f"  2. Flutter: ApiConfig.hostOverride = {lan!r}")
            self.stdout.write(f'     or: flutter run --dart-define=API_HOST={lan}')

        if status['explicit_provider'] == '2factor' and validate_2factor_config():
            self.stderr.write(
                self.style.ERROR(
                    '2Factor is selected but credentials are missing or invalid in backend/.env.'
                )
            )
        elif status['explicit_provider'] == 'infobip' and validate_infobip_config():
            self.stderr.write(
                self.style.ERROR(
                    'Infobip is selected but credentials are missing or invalid in backend/.env.'
                )
            )
        elif status['explicit_provider'] == 'twilio' and validate_twilio_config():
            self.stderr.write(
                self.style.ERROR(
                    'Twilio is selected but credentials are missing or invalid in backend/.env.'
                )
            )
        elif status['explicit_provider'] == '2factor' and is_live_sms():
            self.stdout.write(self.style.SUCCESS('SMS OTP is configured for 2Factor.in live delivery.'))
        elif not is_live_sms():
            self.stderr.write(
                self.style.WARNING(
                    'OTP is NOT sent to the phone in console mode. '
                    'Set SMS_PROVIDER=2factor, SMS_OTP_ENABLED=True, and TWOFACTOR_API_KEY in backend/.env.'
                )
            )
        else:
            self.stdout.write(self.style.SUCCESS('SMS OTP is configured for live delivery to phone.'))
