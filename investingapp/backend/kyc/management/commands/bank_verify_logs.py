"""Print bank verification logs for a user — simple alias for debugging."""

import json

from django.core.management.base import BaseCommand

from accounts.otp_utils import normalize_phone
from kyc.models import VerificationAuditLog


class Command(BaseCommand):
    help = 'Show bank verification logs for a phone number (database audit trail).'

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            default='8285623224',
            help='User phone (10 digits). Default: 8285623224',
        )
        parser.add_argument(
            '--limit',
            type=int,
            default=10,
            help='How many log rows to show (default 10).',
        )

    def handle(self, *args, **options):
        phone = normalize_phone(options['phone'])
        limit = max(1, options['limit'])

        rows = list(
            VerificationAuditLog.objects.filter(
                step=VerificationAuditLog.Step.BANK,
                user__phone=phone,
            ).order_by('-created_at')[:limit]
        )

        self.stdout.write(self.style.HTTP_INFO(f'=== Bank verification logs — {phone} ==='))
        if not rows:
            self.stdout.write(self.style.WARNING('Koi log nahi mila. App se bank verify try karo, phir dubara run karo.'))
            self.stdout.write('')
            self.stdout.write('Command:  python3 manage.py bank_verify_logs --phone ' + phone)
            return

        for row in rows:
            req = row.request_meta or {}
            line = (
                f'{row.created_at:%Y-%m-%d %H:%M:%S} | {row.status.upper():7} | '
                f'{row.message or "(no message)"}'
            )
            if req:
                line += f' | {json.dumps(req, ensure_ascii=False)}'
            if row.status == VerificationAuditLog.Status.FAILED:
                self.stdout.write(self.style.ERROR(line))
            elif row.status == VerificationAuditLog.Status.SUCCESS:
                self.stdout.write(self.style.SUCCESS(line))
            else:
                self.stdout.write(line)

        self.stdout.write('')
        self.stdout.write('Live Eko HTTP logs:  tail -f logs/eko_kyc.log   (backend folder mein)')
        self.stdout.write('Eko dashboard:        https://connect.eko.in → History')
