import time

from django.core.management.base import BaseCommand

from stocks.scalper_service import process_scalper_orders


class Command(BaseCommand):
    help = 'Continuously process scalper limit entries and automatic exits.'

    def add_arguments(self, parser):
        parser.add_argument('--interval', type=float, default=3.0)
        parser.add_argument('--once', action='store_true')

    def handle(self, *args, **options):
        interval = max(1.0, min(float(options['interval']), 60.0))
        run_once = options['once']
        self.stdout.write(f'Scalper monitor started (interval={interval:g}s).')
        try:
            while True:
                processed = process_scalper_orders()
                if processed:
                    self.stdout.write(self.style.SUCCESS(f'Processed {processed} trigger(s).'))
                if run_once:
                    break
                time.sleep(interval)
        except KeyboardInterrupt:
            self.stdout.write(self.style.WARNING('Scalper monitor stopped.'))
