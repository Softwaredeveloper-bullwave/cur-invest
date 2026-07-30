from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import BankAccount, EmailOTPVerification, User
from kyc.models import KYCRequest, KycProfile, VerificationAuditLog


class Command(BaseCommand):
    help = (
        'Reset KYC / email / profile verification state for a user so they can '
        're-run Phone OTP → Email → Profile → PAN → Aadhaar → Bank → UPI → Home.'
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--phone',
            required=True,
            help='10-digit phone number of the user to reset (e.g. 9871013472).',
        )
        parser.add_argument(
            '--keep-profile',
            action='store_true',
            help='Keep name/email/DOB but reset all KYC verification steps only.',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        phone = ''.join(ch for ch in options['phone'] if ch.isdigit())
        if len(phone) == 12 and phone.startswith('91'):
            phone = phone[2:]
        if len(phone) != 10:
            raise CommandError('Enter a valid 10-digit Indian phone number.')

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist:
            raise CommandError(f'No user found with phone {phone}.')

        keep_profile = options['keep_profile']

        deleted = {
            'kyc_profile': KycProfile.objects.filter(user=user).delete()[0],
            'bank_accounts': BankAccount.objects.filter(user=user).delete()[0],
            'email_otps': EmailOTPVerification.objects.filter(user=user).delete()[0],
            'audit_logs': VerificationAuditLog.objects.filter(user=user).delete()[0],
            'manual_kyc': KYCRequest.objects.filter(user=user).delete()[0],
        }

        user.pan_status = User.PanStatus.PENDING
        user.kyc_status = User.KycStatus.NOT_SUBMITTED
        user.fno_status = User.FnoStatus.NOT_SUBMITTED
        user.email_verified = False
        user.has_completed_onboarding = False

        if not keep_profile:
            user.name = ''
            user.email = ''
            user.date_of_birth = None
            user.city = ''
            user.bio = ''

        user.save(
            update_fields=[
                'pan_status',
                'kyc_status',
                'fno_status',
                'email_verified',
                'has_completed_onboarding',
                'name',
                'email',
                'date_of_birth',
                'city',
                'bio',
            ]
        )

        self.stdout.write(self.style.SUCCESS(f'Reset verification flow for {phone}'))
        for label, count in deleted.items():
            self.stdout.write(f'  - removed {count} {label.replace("_", " ")} row(s)')
        if keep_profile:
            self.stdout.write('  - kept name/email/DOB (use without --keep-profile for full reset)')
        else:
            self.stdout.write('  - cleared profile name, email, DOB, city, bio')
        self.stdout.write(
            '\nIn the app: log out (or clear app data), then sign in again with phone OTP '
            'to start Email → Profile → KYC from scratch.'
        )
