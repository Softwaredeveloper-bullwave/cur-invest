"""Twelve Data (or any compatible REST host) — paste FOREX_API_KEY in backend/.env."""

from __future__ import annotations

from datetime import datetime, timezone as dt_timezone
from decimal import Decimal
from typing import Any

import httpx
from django.conf import settings
from django.utils import timezone

from ..pairs import FOREX_PAIRS, PAIR_BY_ID, normalize_pair_id, pair_symbol
from .base import BaseForexProvider, ForexProviderError
from .keys import is_secret_error, twelve_data_api_key

PERIOD_TO_INTERVAL = {
    '1H': '5min',
    '1D': '1h',
    '1W': '4h',
    '1M': '1day',
    '3M': '1day',
    '1Y': '1week',
    'ALL': '1week',
}


def _d(value) -> Decimal:
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal('0')


class TwelveDataProvider(BaseForexProvider):
    name = 'twelvedata'

    def __init__(self):
        self.api_key = twelve_data_api_key()
        self.base_url = (
            getattr(settings, 'FOREX_API_BASE_URL', '') or 'https://api.twelvedata.com'
        ).rstrip('/')
        self.timeout = int(getattr(settings, 'FOREX_API_TIMEOUT', 20) or 20)

    def _get(self, path: str, params: dict | None = None) -> Any:
        if not self.api_key:
            raise ForexProviderError(
                'Twelve Data API key is not set.',
                retryable=True,
                status_code=503,
            )
        query = {'apikey': self.api_key, **(params or {})}
        try:
            with httpx.Client(timeout=self.timeout, follow_redirects=True) as client:
                resp = client.get(
                    f'{self.base_url}{path}',
                    params=query,
                    headers={'Authorization': f'apikey {self.api_key}'},
                )
            data = resp.json() if resp.content else {}
            if resp.status_code == 429 or (isinstance(data, dict) and data.get('code') == 429):
                raise ForexProviderError('Forex API rate limit. Try again shortly.', status_code=429)
            if resp.status_code >= 400 or (isinstance(data, dict) and data.get('status') == 'error'):
                msg = (data.get('message') if isinstance(data, dict) else None) or 'Forex market data unavailable.'
                status_code = 401 if is_secret_error(str(msg)) else resp.status_code
                raise ForexProviderError(
                    'Twelve Data key was rejected.' if is_secret_error(str(msg)) else str(msg)[:300],
                    retryable=True,
                    status_code=status_code,
                )
            return data
        except ForexProviderError:
            raise
        except Exception as exc:
            raise ForexProviderError(f'Forex provider error: {exc}', retryable=True) from exc

    def _quote_row(self, pair_id: str, payload: dict) -> dict[str, Any]:
        meta = PAIR_BY_ID.get(pair_id)
        base, quote, name, category = (meta[1], meta[2], meta[3], meta[4]) if meta else ('', '', pair_id, 'Majors')
        price = _d(payload.get('close') or payload.get('price') or payload.get('current_price'))
        pct = _d(payload.get('percent_change') or payload.get('price_change_percentage_24h') or 0)
        change = _d(payload.get('change') or payload.get('price_change_24h') or 0)
        return {
            'id': pair_id,
            'symbol': pair_symbol(pair_id),
            'name': payload.get('name') or name,
            'base_currency': base,
            'quote_currency': quote,
            'category': category,
            'current_price': price,
            'price_change_24h': change,
            'price_change_percentage_24h': pct,
            'high_24h': _d(payload.get('high') or payload.get('fifty_two_week', {}).get('high') if isinstance(payload.get('fifty_two_week'), dict) else payload.get('high')),
            'low_24h': _d(payload.get('low')),
            'sparkline_7d': [],
            'currency': quote.lower(),
            'image_url': '',
        }

    def get_pairs(self, *, ids: list[str] | None = None) -> list[dict[str, Any]]:
        wanted = [normalize_pair_id(i) for i in ids] if ids else [row[0] for row in FOREX_PAIRS]
        by_symbol: dict[str, dict] = {}
        chunk_size = 8
        for i in range(0, len(wanted), chunk_size):
            chunk = wanted[i : i + chunk_size]
            symbols = ','.join(pair_symbol(pid) for pid in chunk)
            data = self._get('/quote', {'symbol': symbols})
            if isinstance(data, dict) and 'symbol' in data:
                data = {data.get('symbol'): data}
            if not isinstance(data, dict):
                raise ForexProviderError('Unexpected forex quote payload.')
            for key, value in data.items():
                if isinstance(value, dict):
                    by_symbol[str(key).upper().replace(' ', '')] = value
        rows = []
        for pid in wanted:
            sym = pair_symbol(pid).upper().replace(' ', '')
            payload = by_symbol.get(sym) or by_symbol.get(sym.replace('/', '')) or {}
            price = _d(payload.get('close') or payload.get('price') or payload.get('current_price'))
            if payload and price > 0:
                rows.append(self._quote_row(pid, payload))
        if not rows:
            raise ForexProviderError('Twelve Data returned no forex quotes.')
        return rows

    def get_pair(self, pair_id: str) -> dict[str, Any]:
        pid = normalize_pair_id(pair_id)
        rows = self.get_pairs(ids=[pid])
        if not rows:
            raise ForexProviderError(f'Unknown forex pair: {pair_id}', retryable=False, status_code=404)
        return rows[0]

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
        interval = PERIOD_TO_INTERVAL.get((period or '1D').upper(), '1h')
        outputsize = {'1H': 48, '1D': 72, '1W': 80, '1M': 90, '3M': 90, '1Y': 52, 'ALL': 100}.get(
            (period or '1D').upper(), 80
        )
        data = self._get(
            '/time_series',
            {'symbol': pair_symbol(pid), 'interval': interval, 'outputsize': outputsize},
        )
        values = list(reversed(data.get('values') or []))
        candles = []
        prices = []
        for item in values:
            close = _d(item.get('close'))
            if close <= 0:
                continue
            raw_ts = item.get('datetime') or item.get('datetime_utc') or ''
            try:
                dt = datetime.fromisoformat(str(raw_ts).replace(' ', 'T'))
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=dt_timezone.utc)
                ts = int(dt.timestamp() * 1000)
            except Exception:
                ts = int(timezone.now().timestamp() * 1000)
            o, h, l = _d(item.get('open') or close), _d(item.get('high') or close), _d(item.get('low') or close)
            candles.append(
                {
                    't': ts,
                    'o': float(o),
                    'h': float(h),
                    'l': float(l),
                    'c': float(close),
                    'v': float(_d(item.get('volume') or 0)),
                }
            )
            prices.append({'t': ts, 'v': float(close)})
        if not candles:
            raise ForexProviderError('Twelve Data returned no forex candles.')
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
