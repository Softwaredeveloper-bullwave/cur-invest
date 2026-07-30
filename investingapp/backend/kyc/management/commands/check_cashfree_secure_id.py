from django.core.management.base import BaseCommand

from core.integrations.status import _cashfree_secure_id_probe
from services.providers.cashfree_config import cashfree_settings


class Command(BaseCommand):
    help = 'Probe Cashfree Secure ID credentials and IP whitelist (no wallet charge for invalid test account).'

    def handle(self, *args, **options):
        cfg = cashfree_settings()
        self.stdout.write(f'Client ID: {cfg.client_id}')
        self.stdout.write(f'Environment: {cfg.environment}')
        self.stdout.write(f'Base URL: {cfg.secure_id_base_url}')
        self.stdout.write(f'API version: {cfg.api_version}')

        probe = _cashfree_secure_id_probe()
        if probe.get('reachable'):
            self.stdout.write(self.style.SUCCESS('Cashfree Secure ID reachable (IP whitelist OK).'))
        else:
            self.stdout.write(self.style.ERROR('Cashfree Secure ID NOT reachable.'))
        self.stdout.write(f"  code: {probe.get('code')}")
        self.stdout.write(f"  message: {probe.get('message')}")
