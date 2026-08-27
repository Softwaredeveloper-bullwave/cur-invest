class ForexTradingDisabled(Exception):
    pass


def get_trading_provider():
    from django.conf import settings

    if not getattr(settings, 'FOREX_TRADING_ENABLED', False):
        raise ForexTradingDisabled('Live forex trading is disabled. Paper trading only.')
    raise ForexTradingDisabled('No live forex broker is configured.')
