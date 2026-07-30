"""Delete all users and their related data except one keep phone."""

from django.core.management.base import BaseCommand, CommandError
from django.db import connection, transaction

from accounts.models import OTPVerification, User
from accounts.otp_utils import normalize_phone
from adminpanel.models import AdminActionAudit


LEGACY_USER_TABLES = (
    'kyc_kycverification',
)


class Command(BaseCommand):
    help = 'Remove every user (and cascaded app data) except the given phone number.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            default='8285623224',
            help='10-digit phone to keep (default: 8285623224).',
        )
        parser.add_argument(
            '--yes',
            action='store_true',
            help='Required confirmation — without this flag the command only prints a dry run.',
        )
        parser.add_argument(
            '--clear-audit',
            action='store_true',
            default=True,
            help='Clear admin-panel audit log (default: true).',
        )
        parser.add_argument(
            '--no-clear-audit',
            action='store_false',
            dest='clear_audit',
            help='Keep admin-panel audit entries.',
        )

    def _purge_legacy_user_rows(self, user_ids: list[str]) -> int:
        if not user_ids:
            return 0
        removed = 0
        placeholders = ','.join(['%s'] * len(user_ids))
        with connection.cursor() as cursor:
            for table in LEGACY_USER_TABLES:
                cursor.execute(
                    f'DELETE FROM {table} WHERE user_id IN ({placeholders})',
                    user_ids,
                )
                removed += cursor.rowcount
        return removed

    def _detach_reviewer_fks(self, user_ids: list[str]) -> None:
        if not user_ids:
            return
        placeholders = ','.join(['%s'] * len(user_ids))
        sql_statements = (
            f'UPDATE kyc_bankverificationrequest SET reviewed_by_id = NULL WHERE reviewed_by_id IN ({placeholders})',
            f'UPDATE kyc_kycrequest SET reviewed_by_id = NULL WHERE reviewed_by_id IN ({placeholders})',
            f'UPDATE kyc_fnoeligibilityrequest SET reviewed_by_id = NULL WHERE reviewed_by_id IN ({placeholders})',
            f'UPDATE accounts_user SET referred_by_id = NULL WHERE referred_by_id IN ({placeholders})',
            f'UPDATE adminpanel_adminactionaudit SET actor_id = NULL WHERE actor_id IN ({placeholders})',
            f'UPDATE django_admin_log SET user_id = NULL WHERE user_id IN ({placeholders})',
        )
        with connection.cursor() as cursor:
            for sql in sql_statements:
                cursor.execute(sql, user_ids)

    def handle(self, *args, **options):
        keep_phone = normalize_phone(options['phone'])
        if not keep_phone:
            raise CommandError('Invalid --phone value.')

        keep_user = User.objects.filter(phone=keep_phone).first()
        if not keep_user:
            raise CommandError(f'Keep-user {keep_phone} does not exist — aborting.')

        to_delete = User.objects.exclude(phone=keep_phone).order_by('phone')
        delete_phones = list(to_delete.values_list('phone', flat=True))
        delete_ids = [str(pk) for pk in to_delete.values_list('pk', flat=True)]
        delete_count = len(delete_phones)

        self.stdout.write(f'Keep user: {keep_phone} ({keep_user.name or "Unnamed"})')
        self.stdout.write(f'Users to delete ({delete_count}): {", ".join(delete_phones) or "none"}')

        if not options['yes']:
            self.stdout.write(
                self.style.WARNING(
                    '\nDry run only. Re-run with --yes to permanently delete the users above.'
                )
            )
            return

        with transaction.atomic():
            otp_removed, _ = OTPVerification.objects.exclude(phone=keep_phone).delete()
            audit_removed = 0
            if options['clear_audit']:
                audit_removed, _ = AdminActionAudit.objects.all().delete()

            legacy_removed = self._purge_legacy_user_rows(delete_ids)
            self._detach_reviewer_fks(delete_ids)

            deleted_users, per_model = to_delete.delete()

        self.stdout.write(self.style.SUCCESS(f'\nRemoved {delete_count} user account(s).'))
        if otp_removed:
            self.stdout.write(f'  - removed {otp_removed} phone OTP row(s) for other numbers')
        if audit_removed:
            self.stdout.write(f'  - cleared {audit_removed} admin audit row(s)')
        if legacy_removed:
            self.stdout.write(f'  - removed {legacy_removed} legacy KYC verification row(s)')

        if per_model:
            self.stdout.write('  - cascaded deletions:')
            for model_label, count in sorted(per_model.items()):
                if model_label == 'accounts.User':
                    continue
                self.stdout.write(f'      {count:4d}  {model_label}')

        remaining = User.objects.count()
        self.stdout.write(self.style.SUCCESS(f'\nRemaining users in database: {remaining} ({keep_phone})'))
        self.stdout.write('Refresh the admin panel — only the kept user should appear.')
        self.stdout.write(
            'Dev admin 9000000099 is recreated automatically when you open the admin panel in dev mode.'
        )
