from django.core.management.base import BaseCommand

from kyc.models import KycProfile
from kyc.service import _sync_user_name_from_kyc


class Command(BaseCommand):
    help = 'Sync accounts.User.name from verified KYC profile names (PAN / bank / Aadhaar).'

    def handle(self, *args, **options):
        updated = 0
        scanned = 0
        for profile in KycProfile.objects.select_related('user').iterator():
            scanned += 1
            user = profile.user
            before = user.name
            _sync_user_name_from_kyc(user, profile)
            user.refresh_from_db(fields=['name'])
            if user.name != before:
                updated += 1
                self.stdout.write(
                    f'{user.phone}: {before!r} -> {user.name!r} '
                    f'(pan={profile.pan_name!r})'
                )

        self.stdout.write(self.style.SUCCESS(f'Scanned {scanned} profiles; updated {updated} user names.'))
