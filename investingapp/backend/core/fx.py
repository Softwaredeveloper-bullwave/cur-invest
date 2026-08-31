"""USD/INR used to convert crypto and forex paper books for display."""

from __future__ import annotations

from decimal import Decimal

DEFAULT_USD_INR = Decimal('83.50')


def usd_inr_rate() -> Decimal:
    try:
        from stocks.commodity_trading_service import get_usd_inr_rate

        rate = get_usd_inr_rate()
        if rate and Decimal(str(rate)) > 0:
            return Decimal(str(rate))
    except Exception:
        pass
    try:
        from django.conf import settings

        raw = (
            getattr(settings, 'FOREX_USD_INR_RATE', None)
            or getattr(settings, 'CRYPTO_USD_INR_RATE', None)
            or DEFAULT_USD_INR
        )
        rate = Decimal(str(raw or DEFAULT_USD_INR))
        if rate > 0:
            return rate
    except Exception:
        pass
    return DEFAULT_USD_INR
