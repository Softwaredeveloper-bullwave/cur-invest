"""Resolve Twelve Data / Alpha Vantage keys from backend/.env without leaking secrets."""

from __future__ import annotations

from django.conf import settings


def clean_api_key(value: str | None) -> str:
    key = (value or '').strip().strip('"').strip("'")
    if key.lower().startswith('bearer '):
        key = key[7:].strip()
    return key


def twelve_data_api_key() -> str:
    return clean_api_key(
        getattr(settings, 'TWELVE_DATA_API_KEY', '')
        or getattr(settings, 'FOREX_TWELVEDATA_API_KEY', '')
        or getattr(settings, 'FOREX_API_KEY', '')
    )


def alphavantage_api_key() -> str:
    return clean_api_key(
        getattr(settings, 'FOREX_ALPHAVANTAGE_API_KEY', '')
        or getattr(settings, 'ALPHA_VANTAGE_API_KEY', '')
    )


def alphavantage_forex_key() -> str:
    """Dedicated AV key, or FOREX_API_KEY when that value was actually an Alpha Vantage key."""
    return alphavantage_api_key() or twelve_data_api_key()


def is_secret_error(message: str | None) -> bool:
    text = (message or '').lower()
    markers = (
        'apikey',
        'api key',
        'api_key',
        'invalid key',
        'unauthorized',
        'twelvedata.com',
        'alphavantage.co',
        'you can get your free api key',
        'key was rejected',
    )
    return any(marker in text for marker in markers)
