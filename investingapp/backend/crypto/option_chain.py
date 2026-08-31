"""Paper crypto option chain from live USD spot."""

from __future__ import annotations

from datetime import date

from django.core.cache import cache
from django.utils import timezone

from core.synthetic_options import build_synthetic_option_chain

from .services import CryptoService

CATALOG = {
    'bitcoin': {'symbol': 'BTC', 'name': 'Bitcoin', 'vol': 0.08, 'fallback': 97000.0},
    'ethereum': {'symbol': 'ETH', 'name': 'Ethereum', 'vol': 0.09, 'fallback': 3500.0},
    'solana': {'symbol': 'SOL', 'name': 'Solana', 'vol': 0.11, 'fallback': 145.0},
    'ripple': {'symbol': 'XRP', 'name': 'XRP', 'vol': 0.1, 'fallback': 0.62},
    'binancecoin': {'symbol': 'BNB', 'name': 'BNB', 'vol': 0.08, 'fallback': 580.0},
}

_ALIASES = {
    'btc': 'bitcoin',
    'eth': 'ethereum',
    'sol': 'solana',
    'xrp': 'ripple',
    'bnb': 'binancecoin',
}


def _canonical(asset_id: str) -> str:
    aid = (asset_id or '').strip().lower()
    return _ALIASES.get(aid, aid)

CACHE_SECONDS = 120


def is_option_underlying(asset_id: str) -> bool:
    return _canonical(asset_id) in CATALOG


def catalog_rows() -> list[dict]:
    return [
        {'id': key, 'symbol': meta['symbol'], 'name': meta['name']}
        for key, meta in CATALOG.items()
    ]


def _spot(asset_id: str, fallback: float) -> tuple[float, str]:
    try:
        quote = CryptoService().get_price(asset_id, vs_currency='usd')
        px = float(quote.get('current_price') or 0)
        if px > 0:
            return px, 'live'
    except Exception:
        pass
    return fallback, 'fallback'


def get_crypto_option_chain(asset_id: str, expiry: str | None = None) -> dict | None:
    aid = _canonical(asset_id)
    meta = CATALOG.get(aid)
    if not meta:
        return None
    cache_key = f'crypto_option_chain:v1:{aid}:{expiry or "nearest"}'
    cached = cache.get(cache_key)
    if cached is not None:
        return cached
    selected = None
    if expiry:
        try:
            selected = date.fromisoformat(str(expiry)[:10])
        except ValueError:
            selected = None
    spot, source = _spot(aid, meta['fallback'])
    chain = build_synthetic_option_chain(
        symbol=meta['symbol'],
        name=meta['name'],
        spot=spot,
        asset_class='crypto',
        currency='USD',
        unit='USD',
        source=source,
        expiry=selected,
        vol_factor=meta['vol'],
        trade_underlying=aid,
    )
    chain['underlying_id'] = aid
    chain['updated_at'] = timezone.now().isoformat()
    cache.set(cache_key, chain, CACHE_SECONDS)
    return chain
