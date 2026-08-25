"""CoinGecko market-data client (public API; optional Pro key via env)."""

from __future__ import annotations

import logging
import time
from decimal import Decimal, InvalidOperation
from typing import Any

import httpx
from django.conf import settings
from django.core.cache import cache

from .base import BaseCryptoProvider, CryptoProviderError

logger = logging.getLogger('bullwave.crypto')

PERIOD_TO_DAYS = {
    '1H': '0.0417',
    '1D': '1',
    '1W': '7',
    '1M': '30',
    '3M': '90',
    '1Y': '365',
    'ALL': 'max',
}


def _dec(value) -> Decimal | None:
    if value is None:
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None


def _dec0(value) -> Decimal:
    return _dec(value) or Decimal('0')


class CoinGeckoProvider(BaseCryptoProvider):
    name = 'coingecko'

    def __init__(self):
        self.api_key = (getattr(settings, 'CRYPTO_API_KEY', '') or '').strip()
        base = (getattr(settings, 'CRYPTO_API_BASE_URL', '') or '').strip().rstrip('/')
        if not base:
            base = (
                'https://pro-api.coingecko.com/api/v3'
                if self.api_key
                else 'https://api.coingecko.com/api/v3'
            )
        self.base_url = base
        self.timeout = float(getattr(settings, 'CRYPTO_API_TIMEOUT', 20) or 20)
        self.cache_seconds = int(getattr(settings, 'CRYPTO_MARKET_CACHE_SECONDS', 60) or 60)

    def _headers(self) -> dict[str, str]:
        headers = {
            'Accept': 'application/json',
            'User-Agent': 'CapitalBullWave/1.0 (crypto-market-data)',
        }
        if self.api_key:
            # CoinGecko Pro / Demo header
            headers['x-cg-pro-api-key'] = self.api_key
            headers['x-cg-demo-api-key'] = self.api_key
        return headers

    def _get(self, path: str, params: dict | None = None, *, cache_key: str | None = None, ttl: int | None = None):
        ttl = ttl if ttl is not None else self.cache_seconds
        if cache_key:
            cached = cache.get(cache_key)
            if cached is not None:
                return cached

        url = f'{self.base_url}{path}'
        started = time.monotonic()
        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.get(url, params=params or {}, headers=self._headers())
        except httpx.TimeoutException as exc:
            raise CryptoProviderError('Crypto market data timed out.', retryable=True) from exc
        except httpx.HTTPError as exc:
            raise CryptoProviderError('Crypto market data is temporarily unavailable.', retryable=True) from exc

        elapsed_ms = int((time.monotonic() - started) * 1000)
        if response.status_code == 429:
            raise CryptoProviderError(
                'Crypto provider rate limit reached. Please try again shortly.',
                retryable=True,
                status_code=429,
            )
        if response.status_code >= 400:
            raise CryptoProviderError(
                f'Crypto provider error ({response.status_code}).',
                retryable=response.status_code >= 500,
                status_code=response.status_code,
            )
        try:
            data = response.json()
        except ValueError as exc:
            raise CryptoProviderError('Invalid response from crypto provider.', retryable=True) from exc

        if cache_key:
            cache.set(cache_key, data, ttl)
        # Attach timing for health monitor callers
        if isinstance(data, dict):
            data = {**data, '_meta_response_ms': elapsed_ms}
        return data

    def get_market_overview(self) -> dict[str, Any]:
        data = self._get('/global', cache_key='crypto:cg:global', ttl=self.cache_seconds)
        g = (data or {}).get('data') or {}
        total_mcap = (g.get('total_market_cap') or {}).get('usd')
        mcap_change = g.get('market_cap_change_percentage_24h_usd')
        btc_dom = (g.get('market_cap_percentage') or {}).get('btc')
        volume = (g.get('total_volume') or {}).get('usd')
        fear = self.get_fear_greed()
        trending = self.get_trending()
        return {
            'total_market_cap': _dec(total_mcap),
            'market_cap_change_percentage_24h': _dec(mcap_change),
            'btc_dominance': _dec(btc_dom),
            'total_volume': _dec(volume),
            'active_cryptocurrencies': g.get('active_cryptocurrencies'),
            'markets': g.get('markets'),
            'fear_greed': fear,
            'trending': trending[:10],
            'provider': self.name,
            'stale': False,
        }

    def get_assets(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        vs_currency: str = 'usd',
        order: str = 'market_cap_desc',
        ids: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        params: dict[str, Any] = {
            'vs_currency': vs_currency,
            'order': order,
            'per_page': min(max(page_size, 1), 100),
            'page': max(page, 1),
            'sparkline': 'true',
            'price_change_percentage': '24h',
        }
        if ids:
            params['ids'] = ','.join(ids)
            params['per_page'] = min(len(ids), 100)
        key = f'crypto:cg:markets:{vs_currency}:{order}:{page}:{page_size}:{params.get("ids", "")}'
        rows = self._get('/coins/markets', params, cache_key=key, ttl=self.cache_seconds)
        if not isinstance(rows, list):
            return []
        return [self._normalize_market_row(r, vs_currency) for r in rows]

    def get_asset(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        aid = (asset_id or '').strip().lower()
        if not aid:
            raise CryptoProviderError('Missing asset id.', retryable=False, status_code=400)
        params = {
            'localization': 'false',
            'tickers': 'false',
            'market_data': 'true',
            'community_data': 'true',
            'developer_data': 'true',
            'sparkline': 'true',
        }
        data = self._get(f'/coins/{aid}', params, cache_key=f'crypto:cg:coin:{aid}', ttl=self.cache_seconds)
        md = data.get('market_data') or {}
        image = (data.get('image') or {}).get('large') or (data.get('image') or {}).get('small') or ''
        return {
            'id': data.get('id') or aid,
            'symbol': (data.get('symbol') or '').upper(),
            'name': data.get('name') or aid,
            'image_url': image,
            'description': ((data.get('description') or {}).get('en') or '')[:4000],
            'homepage_url': ((data.get('links') or {}).get('homepage') or [''])[0] or '',
            'categories': data.get('categories') or [],
            'market_cap_rank': data.get('market_cap_rank'),
            'current_price': _dec((md.get('current_price') or {}).get(vs_currency)),
            'price_change_percentage_24h': _dec(md.get('price_change_percentage_24h')),
            'high_24h': _dec((md.get('high_24h') or {}).get(vs_currency)),
            'low_24h': _dec((md.get('low_24h') or {}).get(vs_currency)),
            'market_cap': _dec((md.get('market_cap') or {}).get(vs_currency)),
            'fully_diluted_valuation': _dec((md.get('fully_diluted_valuation') or {}).get(vs_currency)),
            'total_volume': _dec((md.get('total_volume') or {}).get(vs_currency)),
            'circulating_supply': _dec(md.get('circulating_supply')),
            'total_supply': _dec(md.get('total_supply')),
            'max_supply': _dec(md.get('max_supply')),
            'ath': _dec((md.get('ath') or {}).get(vs_currency)),
            'atl': _dec((md.get('atl') or {}).get(vs_currency)),
            'sparkline_7d': ((md.get('sparkline_7d') or {}).get('price') or [])[:168],
            'community': {
                'twitter_followers': (data.get('community_data') or {}).get('twitter_followers'),
                'reddit_subscribers': (data.get('community_data') or {}).get('reddit_subscribers'),
            },
            'developer': {
                'forks': (data.get('developer_data') or {}).get('forks'),
                'stars': (data.get('developer_data') or {}).get('stars'),
                'subscribers': (data.get('developer_data') or {}).get('subscribers'),
                'commit_count_4_weeks': (data.get('developer_data') or {}).get('commit_count_4_weeks'),
            },
            'currency': vs_currency,
            'provider': self.name,
        }

    def get_price(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        asset = self.get_asset(asset_id, vs_currency=vs_currency)
        return {
            'id': asset['id'],
            'symbol': asset['symbol'],
            'current_price': asset['current_price'],
            'price_change_percentage_24h': asset['price_change_percentage_24h'],
            'currency': vs_currency,
            'provider': self.name,
        }

    def get_ohlcv(
        self,
        asset_id: str,
        *,
        vs_currency: str = 'usd',
        days: str = '1',
    ) -> dict[str, Any]:
        aid = (asset_id or '').strip().lower()
        day_param = PERIOD_TO_DAYS.get(days.upper(), days) if days else '1'
        params = {'vs_currency': vs_currency, 'days': day_param}
        data = self._get(
            f'/coins/{aid}/market_chart',
            params,
            cache_key=f'crypto:cg:chart:{aid}:{vs_currency}:{day_param}',
            ttl=max(self.cache_seconds, 120),
        )
        prices = data.get('prices') or []
        volumes = data.get('total_volumes') or []
        return {
            'id': aid,
            'currency': vs_currency,
            'period': days,
            'prices': [{'t': int(p[0]), 'v': float(p[1])} for p in prices if len(p) >= 2],
            'volumes': [{'t': int(v[0]), 'v': float(v[1])} for v in volumes if len(v) >= 2],
            'provider': self.name,
        }

    def get_market_stats(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        return self.get_asset(asset_id, vs_currency=vs_currency)

    def get_trending(self) -> list[dict[str, Any]]:
        data = self._get('/search/trending', cache_key='crypto:cg:trending', ttl=self.cache_seconds)
        coins = data.get('coins') or []
        out = []
        for item in coins:
            c = item.get('item') or {}
            out.append(
                {
                    'id': c.get('id'),
                    'symbol': (c.get('symbol') or '').upper(),
                    'name': c.get('name'),
                    'image_url': c.get('large') or c.get('thumb') or '',
                    'market_cap_rank': c.get('market_cap_rank'),
                    'score': c.get('score'),
                }
            )
        return out

    def get_top_gainers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        rows = self.get_assets(page=1, page_size=100, vs_currency=vs_currency, order='market_cap_desc')
        ranked = sorted(
            rows,
            key=lambda r: float(r.get('price_change_percentage_24h') or 0),
            reverse=True,
        )
        return ranked[:limit]

    def get_top_losers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        rows = self.get_assets(page=1, page_size=100, vs_currency=vs_currency, order='market_cap_desc')
        ranked = sorted(
            rows,
            key=lambda r: float(r.get('price_change_percentage_24h') or 0),
        )
        return ranked[:limit]

    def get_volume_data(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        return self.get_assets(
            page=1, page_size=limit, vs_currency=vs_currency, order='volume_desc'
        )

    def search(self, query: str) -> list[dict[str, Any]]:
        q = (query or '').strip()
        if len(q) < 1:
            return []
        data = self._get('/search', {'query': q}, cache_key=f'crypto:cg:search:{q.lower()}', ttl=300)
        coins = data.get('coins') or []
        return [
            {
                'id': c.get('id'),
                'symbol': (c.get('symbol') or '').upper(),
                'name': c.get('name'),
                'image_url': c.get('large') or c.get('thumb') or '',
                'market_cap_rank': c.get('market_cap_rank'),
            }
            for c in coins[:40]
        ]

    def get_fear_greed(self) -> dict[str, Any] | None:
        """Alternative.me Crypto Fear & Greed Index (public, no key)."""
        cached = cache.get('crypto:fear_greed')
        if cached is not None:
            return cached
        try:
            with httpx.Client(timeout=10) as client:
                resp = client.get('https://api.alternative.me/fng/?limit=1')
            if resp.status_code != 200:
                return None
            payload = resp.json()
            row = (payload.get('data') or [None])[0]
            if not row:
                return None
            result = {
                'value': int(row.get('value') or 0),
                'classification': row.get('value_classification') or '',
                'timestamp': row.get('timestamp'),
            }
            cache.set('crypto:fear_greed', result, 600)
            return result
        except Exception:
            logger.debug('Fear & Greed fetch failed', exc_info=True)
            return None

    def _normalize_market_row(self, row: dict, vs_currency: str) -> dict[str, Any]:
        spark = ((row.get('sparkline_in_7d') or {}).get('price') or [])[-48:]
        return {
            'id': row.get('id'),
            'symbol': (row.get('symbol') or '').upper(),
            'name': row.get('name'),
            'image_url': row.get('image') or '',
            'current_price': _dec(row.get('current_price')),
            'price_change_24h': _dec(row.get('price_change_24h')),
            'price_change_percentage_24h': _dec(row.get('price_change_percentage_24h')),
            'high_24h': _dec(row.get('high_24h')),
            'low_24h': _dec(row.get('low_24h')),
            'market_cap': _dec(row.get('market_cap')),
            'fully_diluted_valuation': _dec(row.get('fully_diluted_valuation')),
            'total_volume': _dec(row.get('total_volume')),
            'circulating_supply': _dec(row.get('circulating_supply')),
            'total_supply': _dec(row.get('total_supply')),
            'max_supply': _dec(row.get('max_supply')),
            'ath': _dec(row.get('ath')),
            'atl': _dec(row.get('atl')),
            'market_cap_rank': row.get('market_cap_rank'),
            'sparkline_7d': spark,
            'currency': vs_currency,
            'provider': self.name,
        }
