import logging

from django.apps import AppConfig

logger = logging.getLogger('bullwave.crypto')


class CryptoConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'crypto'
    verbose_name = 'Crypto Markets'

    def ready(self):
        from django.conf import settings

        provider = (getattr(settings, 'CRYPTO_DATA_PROVIDER', 'coingecko') or 'coingecko').lower()
        logger.info('Crypto market data provider: %s', provider)
