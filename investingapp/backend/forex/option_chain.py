"""Paper forex option chain from live pair quotes."""

from __future__ import annotations

from datetime import date

from django.core.cache import cache
from django.utils import timezone

from core.synthetic_options import build_synthetic_option_chain

from .pairs import normalize_pair_id
from .services import ForexService

CATALOG = {
    'eurusd': {'symbol': 'EUR/USD', 'name': 'Euro / US Dollar', 'vol': 0.012, 'fallback': 1.16},
    'gbpusd': {'symbol': 'GBP/USD', 'name': 'British Pound / US Dollar', 'vol': 0.013, 'fallback': 1.31},
    'usdjpy': {'symbol': 'USD/JPY', 'name': 'US Dollar / Japanese Yen', 'vol': 0.011, 'fallback': 149.5},
    'usdinr': {'symbol': 'USD/INR', 'name': 'US Dollar / Indian Rupee', 'vol': 0.01, 'fallback': 83.5},
    'audusd': {'symbol': 'AUD/USD', 'name': 'Australian Dollar / US Dollar', 'vol': 0.014, 'fallback': 0.66},
}

CACHE_SECONDS = 120


def is_option_underlying(pair_id: str) -> bool:
    return normalize_pair_id(pair_id or '') in CATALOG


def catalog_rows() -> list[dict]:
    return [
        {'id': key, 'symbol': meta['symbol'], 'name': meta['name']}
        for key, meta in CATALOG.items()
    ]


def _spot(pair_id: str, fallback: float) -> tuple[float, str]:
    try:
        quote = ForexService().get_price(pair_id)
        px = float(quote.get('current_price') or 0)
        if px > 0:
            return px, 'live'
    except Exception:
        pass
    return fallback, 'fallback'


def get_forex_option_chain(pair_id: str, expiry: str | None = None) -> dict | None:
    pid = normalize_pair_id(pair_id or '')
    meta = CATALOG.get(pid)
    if not meta:
        return None
    cache_key = f'forex_option_chain:v1:{pid}:{expiry or "nearest"}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    selected = None
    if expiry:
        try:
            selected = date.fromisoformat(str(expiry)[:10])
        except ValueError:
            selected = None
    spot, source = _spot(pid, meta['fallback'])
    chain = build_synthetic_option_chain(
        symbol=meta['symbol'],
        name=meta['name'],
        spot=spot,
        asset_class='forex',
        currency='USD',
        unit=meta['symbol'],
        source=source,
        expiry=selected,
        vol_factor=meta['vol'],
        trade_underlying=pid,
    )
    chain['underlying_id'] = pid
    chain['updated_at'] = timezone.now().isoformat()
    cache.set(cache_key, chain, CACHE_SECONDS)
    return chain
