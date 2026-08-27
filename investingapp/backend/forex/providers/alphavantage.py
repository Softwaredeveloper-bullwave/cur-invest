"""Alpha Vantage FX — uses ALPHA_VANTAGE_API_KEY (same key as Indian stocks)."""

from __future__ import annotations

from datetime import datetime, timezone as dt_timezone
from decimal import Decimal
from typing import Any
import time

import httpx
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from ..pairs import FOREX_PAIRS, PAIR_BY_ID, normalize_pair_id, pair_symbol
from .base import BaseForexProvider, ForexProviderError
from .keys import alphavantage_forex_key, is_secret_error

BASE_URL = 'https://www.alphavantage.co/query'
QUOTE_CACHE_PREFIX = 'fx:av:quote:'


def _d(value) -> Decimal:
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal('0')


def _can_call() -> bool:
    delay = int(getattr(settings, 'ALPHA_VANTAGE_REQUEST_DELAY_SECONDS', 12) or 12)
    last = cache.get('av:last_request_ts')
    if last is None:
        return True
    return (time.time() - float(last)) >= max(delay, 1)


class AlphaVantageForexProvider(BaseForexProvider):
    name = 'alphavantage'

    def __init__(self):
        self.api_key = alphavantage_forex_key()
        self.timeout = int(getattr(settings, 'FOREX_API_TIMEOUT', 20) or 20)

    def _get(self, params: dict) -> dict:
        if not self.api_key:
            raise ForexProviderError('ALPHA_VANTAGE_API_KEY is not set.', retryable=False, status_code=503)
        if not _can_call():
            raise ForexProviderError('Alpha Vantage rate window busy.', retryable=True, status_code=429)
        query = {**params, 'apikey': self.api_key}
        try:
            with httpx.Client(timeout=self.timeout, follow_redirects=True) as client:
                resp = client.get(BASE_URL, params=query)
            cache.set('av:last_request_ts', time.time(), 120)
            data = resp.json() if resp.content else {}
        except ForexProviderError:
            raise
        except Exception as exc:
            raise ForexProviderError(f'Alpha Vantage forex error: {exc}', retryable=True) from exc

        if not isinstance(data, dict):
            raise ForexProviderError('Unexpected Alpha Vantage forex payload.')
        if resp.status_code == 429:
            raise ForexProviderError('Alpha Vantage rate limit. Try again shortly.', status_code=429)
        err = data.get('Error Message') or data.get('Note') or data.get('Information') or ''
        if err:
            msg = str(err)
            if is_secret_error(msg) or 'invalid' in msg.lower():
                raise ForexProviderError('Alpha Vantage forex key was rejected.', retryable=True, status_code=401)
            if 'frequency' in msg.lower() or 'premium' in msg.lower() or 'rate' in msg.lower():
                raise ForexProviderError('Alpha Vantage rate limit. Try again shortly.', status_code=429)
            raise ForexProviderError('Alpha Vantage forex data unavailable.', retryable=True)
        return data

    def _quote_row(self, pair_id: str, rate: Decimal, *, bid: Decimal | None = None, ask: Decimal | None = None) -> dict[str, Any]:
        meta = PAIR_BY_ID.get(pair_id)
        base, quote, name, category = (meta[1], meta[2], meta[3], meta[4]) if meta else ('', '', pair_id, 'Majors')
        return {
            'id': pair_id,
            'symbol': pair_symbol(pair_id),
            'name': name,
            'base_currency': base,
            'quote_currency': quote,
            'category': category,
            'current_price': rate,
            'price_change_24h': Decimal('0'),
            'price_change_percentage_24h': Decimal('0'),
            'high_24h': ask if ask else rate,
            'low_24h': bid if bid else rate,
            'sparkline_7d': [],
            'currency': quote.lower(),
            'image_url': '',
        }

    def _fetch_rate(self, pair_id: str) -> dict[str, Any]:
        pid = normalize_pair_id(pair_id)
        meta = PAIR_BY_ID.get(pid)
        if not meta:
            raise ForexProviderError(f'Unknown forex pair: {pair_id}', retryable=False, status_code=404)
        data = self._get(
            {
                'function': 'CURRENCY_EXCHANGE_RATE',
                'from_currency': meta[1],
                'to_currency': meta[2],
            }
        )
        payload = data.get('Realtime Currency Exchange Rate') or {}
        rate = _d(payload.get('5. Exchange Rate'))
        if rate <= 0:
            raise ForexProviderError(f'Alpha Vantage returned no rate for {pid}.')
        row = self._quote_row(
            pid,
            rate,
            bid=_d(payload.get('8. Bid Price')) or None,
            ask=_d(payload.get('9. Ask Price')) or None,
        )
        ttl = int(getattr(settings, 'ALPHA_VANTAGE_QUOTE_CACHE_SECONDS', 120) or 120)
        cache.set(f'{QUOTE_CACHE_PREFIX}{pid}', row, ttl)
        return row

    def get_pairs(self, *, ids: list[str] | None = None) -> list[dict[str, Any]]:
        wanted = [normalize_pair_id(i) for i in ids] if ids else [row[0] for row in FOREX_PAIRS]
        rows: list[dict[str, Any]] = []
        missing: list[str] = []
        for pid in wanted:
            cached = cache.get(f'{QUOTE_CACHE_PREFIX}{pid}')
            if cached:
                rows.append(cached)
            else:
                missing.append(pid)
        budget = int(getattr(settings, 'ALPHA_VANTAGE_MAX_QUOTES_PER_REFRESH', 5) or 5)
        for pid in missing[: max(budget, 1)]:
            try:
                rows.append(self._fetch_rate(pid))
            except ForexProviderError:
                break
        if not any(_d(r.get('current_price')) > 0 for r in rows):
            raise ForexProviderError('Alpha Vantage returned no forex quotes.')
        return rows

    def get_pair(self, pair_id: str) -> dict[str, Any]:
        pid = normalize_pair_id(pair_id)
        cached = cache.get(f'{QUOTE_CACHE_PREFIX}{pid}')
        if cached:
            return cached
        return self._fetch_rate(pid)

    def get_price(self, pair_id: str) -> dict[str, Any]:
        return self.get_pair(pair_id)

    def get_market_overview(self) -> dict[str, Any]:
        pairs = self.get_pairs()
        gainers = sorted(pairs, key=lambda r: r['price_change_percentage_24h'], reverse=True)
        return {
            'total_pairs': len(pairs),
            'majors': [r for r in pairs if r['category'] == 'Majors'],
            'trending': gainers[:5],
            'top_gainers': gainers[:5],
            'top_losers': list(reversed(gainers[-5:])),
            'provider': self.name,
        }

    def get_ohlcv(self, pair_id: str, *, period: str = '1D') -> dict[str, Any]:
        pid = normalize_pair_id(pair_id)
        meta = PAIR_BY_ID.get(pid)
        if not meta:
            raise ForexProviderError(f'Unknown forex pair: {pair_id}', retryable=False, status_code=404)
        period_u = (period or '1D').upper()
        if period_u in ('1H', '1D'):
            data = self._get(
                {
                    'function': 'FX_INTRADAY',
                    'from_symbol': meta[1],
                    'to_symbol': meta[2],
                    'interval': '5min',
                    'outputsize': 'compact',
                }
            )
            series = data.get('Time Series FX (5min)') or {}
        else:
            data = self._get(
                {
                    'function': 'FX_DAILY',
                    'from_symbol': meta[1],
                    'to_symbol': meta[2],
                    'outputsize': 'compact',
                }
            )
            series = data.get('Time Series FX (Daily)') or {}
        if not series:
            raise ForexProviderError('Alpha Vantage returned no forex candles.')
        candles = []
        prices = []
        for stamp, item in sorted(series.items()):
            if not isinstance(item, dict):
                continue
            close = _d(item.get('4. close'))
            if close <= 0:
                continue
            try:
                dt = datetime.fromisoformat(str(stamp).replace(' ', 'T'))
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=dt_timezone.utc)
                ts = int(dt.timestamp() * 1000)
            except Exception:
                ts = int(timezone.now().timestamp() * 1000)
            o, h, l = _d(item.get('1. open') or close), _d(item.get('2. high') or close), _d(item.get('3. low') or close)
            candles.append(
                {
                    't': ts,
                    'o': float(o),
                    'h': float(h),
                    'l': float(l),
                    'c': float(close),
                    'v': 0.0,
                }
            )
            prices.append({'t': ts, 'v': float(close)})
        if not candles:
            raise ForexProviderError('Alpha Vantage returned no forex candles.')
        return {'asset_id': pid, 'pair_id': pid, 'period': period, 'candles': candles, 'prices': prices}

    def get_trending(self) -> list[dict[str, Any]]:
        return self.get_market_overview()['trending']

    def get_top_gainers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        return sorted(self.get_pairs(), key=lambda r: r['price_change_percentage_24h'], reverse=True)[:limit]

    def get_top_losers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        return sorted(self.get_pairs(), key=lambda r: r['price_change_percentage_24h'])[:limit]

    def search(self, query: str) -> list[dict[str, Any]]:
        q = (query or '').strip().lower().replace('/', '')
        if not q:
            return []
        return [
            r
            for r in self.get_pairs()
            if q in r['id'] or q in r['symbol'].lower().replace('/', '') or q in r['name'].lower()
        ]
