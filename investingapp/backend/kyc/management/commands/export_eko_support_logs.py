"""Export sanitized bank-verification logs for Eko Connect support email."""

from datetime import datetime, timezone
from pathlib import Path

from django.core.management.base import BaseCommand

from accounts.otp_utils import normalize_phone
from kyc.eko_support_export import build_eko_support_report


class Command(BaseCommand):
    help = (
        'Create a text file with bank verification logs to email Eko Connect support. '
        'No API secrets are included.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            default='8285623224',
            help='User phone for attempt timeline (10 digits). Default: 8285623224',
        )
        parser.add_argument(
            '--output',
            default='',
            help='Output file path (default: exports/eko_support_<phone>_<timestamp>.txt)',
        )
        parser.add_argument(
            '--audit-limit',
            type=int,
            default=50,
            help='Max bank audit rows per user (default 50).',
        )
        parser.add_argument(
            '--log-lines',
            type=int,
            default=400,
            help='Max Eko HTTP log lines to include (default 400).',
        )
        parser.add_argument(
            '--include-global',
            action='store_true',
            help='Also append recent bank attempts from all users (when --phone omitted).',
        )

    def handle(self, *args, **options):
        phone = normalize_phone(options['phone']) if options['phone'] else ''
        stamp = datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')
        default_name = f'eko_support_{phone or "merchant"}_{stamp}.txt'
        output = Path(options['output'] or Path('exports') / default_name)
        output.parent.mkdir(parents=True, exist_ok=True)

        report = build_eko_support_report(
            phone=phone,
            audit_limit=max(1, options['audit_limit']),
            log_line_limit=max(50, options['log_lines']),
            include_global_audit=options['include_global'],
        )
        output.write_text(report, encoding='utf-8')

        self.stdout.write(self.style.SUCCESS(f'Export written: {output.resolve()}'))
        self.stdout.write('')
        self.stdout.write('Email this file to: cs@eko.co.in')
        self.stdout.write('Subject suggestion: Bank Verification API failures — BullWave Capital')
        self.stdout.write('')
        self.stdout.write('Preview (first 40 lines):')
        self.stdout.write('-' * 60)
        for line in report.splitlines()[:40]:
            self.stdout.write(line)
        if report.count('\n') > 40:
            self.stdout.write('...')
            self.stdout.write(f'({report.count(chr(10))} lines total — see file for full export)')
