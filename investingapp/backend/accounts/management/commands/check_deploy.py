from django.core.management.base import BaseCommand

from core.db_health import database_status
from core.integrations.sms_service import sms_config_status


class Command(BaseCommand):
    help = 'Verify production readiness: WSGI loaded, database reachable, SMS config.'

    def handle(self, *args, **options):
        db = database_status()
        sms = sms_config_status()

        self.stdout.write(f"Database reachable={db.get('reachable')}")
        if not db.get('reachable'):
            self.stderr.write(self.style.ERROR(f"  {db.get('message', 'Database unreachable')}"))

        self.stdout.write(f"SMS provider={sms['provider']} mode={sms['mode']}")
        for problem in (sms.get('infobip_problems') or []) + (sms.get('twilio_problems') or []):
            self.stderr.write(self.style.ERROR(f'  SMS: {problem}'))

        if db.get('reachable'):
            self.stdout.write(self.style.SUCCESS('Deploy check passed (DB + settings load).'))
        else:
            self.stderr.write(
                self.style.ERROR(
                    'Deploy check failed — fix DB_* in backend/.env and ensure PostgreSQL/RDS is reachable.'
                )
            )
