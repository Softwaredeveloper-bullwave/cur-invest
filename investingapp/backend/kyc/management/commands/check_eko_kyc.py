"""Diagnose Eko Connect KYC config, bank provider routing, and where to find API logs."""

import json

from django.conf import settings
from django.core.management.base import BaseCommand

from kyc.models import VerificationAuditLog
from kyc.providers import bank_provider, step_providers_payload
from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import eko_kyc_billing_status


class Command(BaseCommand):
    help = (
        'Show Eko Connect KYC configuration, confirm bank verification uses Eko, '
        'and print steps to view Eko API logs (terminal, log file, DB audit, Eko dashboard).'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--audit',
            action='store_true',
            help='Show recent bank verification audit rows from the database.',
        )
        parser.add_argument(
            '--audit-limit',
            type=int,
            default=10,
            help='Number of audit rows to show with --audit (default 10).',
        )
        parser.add_argument(
            '--phone',
            default='',
            help='Filter audit logs to a user phone number (10 digits).',
        )

    def handle(self, *args, **options):
        cfg = eko_settings()
        providers = step_providers_payload()
        billing = eko_kyc_billing_status()

        self.stdout.write(self.style.HTTP_INFO('=== Eko Connect — KYC configuration ==='))
        self.stdout.write(f'Bank verification provider : {bank_provider()}')
        self.stdout.write(f'All step providers         : {json.dumps(providers, indent=2)}')
        self.stdout.write('')
        self.stdout.write(f'EKO_ENVIRONMENT            : {cfg.environment}')
        self.stdout.write(f'EKO_BASE_URL               : {cfg.base_url or "(not set)"}')
        self.stdout.write(f'EKO_INITIATOR_ID           : {cfg.initiator_id or "(not set)"}')
        self.stdout.write(f'EKO_USER_CODE              : {cfg.user_code or "(not set)"}')
        self.stdout.write(
            f'EKO_DEVELOPER_KEY          : {"set (" + cfg.developer_key[:6] + "...)" if cfg.developer_key else "MISSING"}'
        )
        self.stdout.write(
            f'EKO_ACCESS_KEY             : {"set (" + cfg.access_key[:6] + "...)" if cfg.access_key else "MISSING"}'
        )
        self.stdout.write(f'EKO_ORG_SLUG               : {cfg.org_slug or "(empty — penny-less disabled)"}')
        self.stdout.write(f'EKO_PENNYLESS_ENABLED      : {cfg.penniless_enabled}')
        self.stdout.write(f'EKO_PENNYLESS_PATH         : {cfg.penniless_path or "(auto from slug)"}')
        self.stdout.write(f'Eko configured             : {cfg.is_configured}')
        self.stdout.write('')

        if bank_provider() != 'eko':
            self.stdout.write(
                self.style.ERROR(
                    'Bank verification is NOT routed to Eko. Set KYC_BANK_PROVIDER=eko in backend/.env '
                    'and restart the Django server.'
                )
            )
        elif not cfg.is_configured:
            self.stdout.write(
                self.style.ERROR(
                    'KYC_BANK_PROVIDER=eko but EKO_* keys are incomplete. Paste keys from '
                    'https://connect.eko.in into backend/.env'
                )
            )
        else:
            self.stdout.write(self.style.SUCCESS('Bank verification is routed to Eko Connect.'))

        if not cfg.org_slug:
            self.stdout.write(
                self.style.WARNING(
                    'EKO_ORG_SLUG is empty — Eko will use penny-drop (₹1 IMPS) instead of penny-less. '
                    'Get your org slug from Eko Connect or cs@eko.co.in and add EKO_ORG_SLUG=touras (example) to .env.'
                )
            )

        self.stdout.write('')
        self.stdout.write(self.style.HTTP_INFO('=== Eko bank API endpoints (when provider=eko) ==='))
        bank_info = billing.get('steps', {}).get('bank', {})
        for key in ('api', 'walletLabel', 'activate'):
            if bank_info.get(key):
                self.stdout.write(f'  {key}: {bank_info[key]}')

        self.stdout.write('')
        self.stdout.write(self.style.HTTP_INFO('=== How to view Eko API logs ==='))
        self._print_log_instructions()

        if options['audit']:
            self.stdout.write('')
            self.stdout.write(self.style.HTTP_INFO('=== Recent bank verification audit (database) ==='))
            self._print_audit(options['audit_limit'], options['phone'])

    def _print_log_instructions(self):
        log_file = (getattr(settings, 'EKO_API_LOG_FILE', '') or '').strip()
        log_level = getattr(settings, 'EKO_LOG_LEVEL', 'INFO')

        self.stdout.write('')
        self.stdout.write('1) Django server terminal (live Eko HTTP calls)')
        self.stdout.write('   Start backend:  python manage.py runserver')
        self.stdout.write('   Trigger bank verify in the app (KYC bank step or POST /api/v1/verify-bank/)')
        self.stdout.write('   Watch lines tagged:  bullwave.kyc')
        self.stdout.write('   Example log lines:')
        self.stdout.write('     Eko POST /v3/tools/kyc/.../bank-acc-verify-penniless -> HTTP 200 ...')
        self.stdout.write('     Eko penniless verify account=****1234 ifsc=HDFC0001234 path=...')
        self.stdout.write('     Eko penny-drop verify account=****1234 ifsc=...')
        self.stdout.write('')
        self.stdout.write(f'2) Log level (current: {log_level})')
        self.stdout.write('   Set in backend/.env:  EKO_LOG_LEVEL=DEBUG   (more detail)')
        self.stdout.write('   Restart Django after changing.')
        self.stdout.write('')
        if log_file:
            self.stdout.write(f'3) Log file: {log_file}')
            self.stdout.write(f'   tail -f {log_file}')
        else:
            self.stdout.write('3) Optional log file — add to backend/.env:')
            self.stdout.write('   EKO_API_LOG_FILE=logs/eko_kyc.log')
            self.stdout.write('   mkdir -p logs && restart Django')
            self.stdout.write('   tail -f logs/eko_kyc.log')
        self.stdout.write('')
        self.stdout.write('4) Database audit trail (success/fail, no raw Eko body)')
        self.stdout.write('   python manage.py check_eko_kyc --audit')
        self.stdout.write('   python manage.py check_eko_kyc --audit --phone 8285623224')
        self.stdout.write('   Django admin: KYC > Verification audit logs')
        self.stdout.write('')
        self.stdout.write('5) Eko Connect dashboard (billing + product enablement)')
        self.stdout.write('   https://connect.eko.in  →  History / Wallet')
        self.stdout.write('   Look for debits labelled "Bank Verification" or "Penny Drop"')
        self.stdout.write('   If missing: email cs@eko.co.in to enable Bank Verification product')
        self.stdout.write('')
        self.stdout.write('6) One-time service activation (PAN/UPI — not bank)')
        self.stdout.write('   python manage.py activate_eko_kyc_services')
        self.stdout.write('   python manage.py list_eko_services --enabled')

    def _print_audit(self, limit: int, phone: str):
        qs = VerificationAuditLog.objects.filter(step=VerificationAuditLog.Step.BANK).order_by('-created_at')
        if phone:
            from accounts.otp_utils import normalize_phone

            phone = normalize_phone(phone)
            qs = qs.filter(user__phone=phone)
        rows = list(qs[: max(1, limit)])
        if not rows:
            self.stdout.write(self.style.WARNING('No bank audit logs found.'))
            return
        for row in rows:
            self.stdout.write(
                f'  {row.created_at:%Y-%m-%d %H:%M:%S} | user={row.user.phone} | '
                f'status={row.status} | {row.message[:120] if row.message else ""}'
            )
            if row.request_meta:
                self.stdout.write(f'    request: {row.request_meta}')
            if row.response_meta:
                self.stdout.write(f'    response: {row.response_meta}')
