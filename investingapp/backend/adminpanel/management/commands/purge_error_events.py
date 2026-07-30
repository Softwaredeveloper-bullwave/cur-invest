from datetime import timedelta

from django.core.management.base import BaseCommand
from django.utils import timezone

from adminpanel.models import ApplicationErrorEvent


class Command(BaseCommand):
    help = 'Delete application error events older than the retention period.'

    def add_arguments(self, parser):
        parser.add_argument('--days', type=int, default=90)

    def handle(self, *args, **options):
        days = max(1, options['days'])
        cutoff = timezone.now() - timedelta(days=days)
        deleted, _ = ApplicationErrorEvent.objects.filter(last_seen_at__lt=cutoff).delete()
        self.stdout.write(self.style.SUCCESS(f'Deleted {deleted} error events older than {days} days.'))
