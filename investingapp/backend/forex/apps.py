import logging

from django.apps import AppConfig

logger = logging.getLogger('bullwave.forex')


class ForexConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'forex'
    verbose_name = 'Forex Markets'

    def ready(self):
        from django.conf import settings

        provider = (getattr(settings, 'FOREX_DATA_PROVIDER', 'auto') or 'auto').lower()
        logger.info('Forex market data provider: %s', provider)
