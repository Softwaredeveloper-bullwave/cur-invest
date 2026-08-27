"""ECB Frankfurter rates — free, no API key. Used when FOREX_API_KEY is empty."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone as dt_timezone
from decimal import Decimal
from typing import Any

import httpx
from django.utils import timezone

from ..pairs import FOREX_PAIRS, normalize_pair_id, pair_symbol
from .base import BaseForexProvider, ForexProviderError

BASE_URL = 'https://api.frankfurter.app'


def _d(value) -> Decimal:
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal('0')


class FrankfurterProvider(BaseForexProvider):
    name = 'frankfurter'

    def _get(self, path: str, params: dict | None = None) -> dict:
        try:
            with httpx.Client(timeout=15, follow_redirects=True) as client:
                resp = client.get(f'{BASE_URL}{path}', params=params or {})
            if resp.status_code >= 400:
                raise ForexProviderError(
                    'Forex rates are temporarily unavailable. Please try again.',
                    status_code=resp.status_code,
                )
            return resp.json()
        except ForexProviderError:
            raise
        except Exception as exc:
            raise ForexProviderError(f'Forex provider error: {exc}', retryable=True) from exc

    def _usd_book(self) -> dict[str, Decimal]:
        data = self._get('/latest', {'from': 'USD'})
        rates = {k.upper(): _d(v) for k, v in (data.get('rates') or {}).items()}
        rates['USD'] = Decimal('1')
        return rates

    def _pair_rate(self, base: str, quote: str, usd: dict[str, Decimal]) -> Decimal:
        b, q = base.upper(), quote.upper()
        ub, uq = usd.get(b), usd.get(q)
        if ub is None or uq is None or ub == 0:
            return Decimal('0')
        # USD book: rate[X] = X per 1 USD. XUSD = 1/rate[X], USDX = rate[X], XY = rate[Y]/rate[X]
        return (uq / ub).quantize(Decimal('0.000001'))

    def _rows(self, *, ids: list[str] | None = None) -> list[dict[str, Any]]:
        usd = self._usd_book()
        yesterday = (timezone.now() - timedelta(days=1)).date().isoformat()
        prev = {}
        try:
            prev_data = self._get(f'/{yesterday}', {'from': 'USD'})
            prev = {k.upper(): _d(v) for k, v in (prev_data.get('rates') or {}).items()}
            prev['USD'] = Decimal('1')
        except ForexProviderError:
            prev = usd
        wanted = {normalize_pair_id(i) for i in ids} if ids else None
        rows = []
        for pid, base, quote, name, category in FOREX_PAIRS:
            if wanted and pid not in wanted:
                continue
            price = self._pair_rate(base, quote, usd)
            yest = self._pair_rate(base, quote, prev) if prev else price
            change = price - yest
            pct = (change / yest * 100) if yest else Decimal('0')
            rows.append(
                {
                    'id': pid,
                    'symbol': f'{base}/{quote}',
                    'name': name,
                    'base_currency': base,
                    'quote_currency': quote,
                    'category': category,
                    'current_price': price,
                    'price_change_24h': change,
                    'price_change_percentage_24h': pct.quantize(Decimal('0.01')),
                    'high_24h': max(price, yest),
                    'low_24h': min(price, yest),
                    'sparkline_7d': [float(yest), float(price)],
                    'currency': quote.lower(),
                    'image_url': '',
                }
            )
        return rows

    def get_pairs(self, *, ids: list[str] | None = None) -> list[dict[str, Any]]:
        return self._rows(ids=ids)

    def get_pair(self, pair_id: str) -> dict[str, Any]:
        pid = normalize_pair_id(pair_id)
        rows = self._rows(ids=[pid])
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
        from ..pairs import PAIR_BY_ID

        row = PAIR_BY_ID.get(pid)
        if not row:
            raise ForexProviderError(f'Unknown forex pair: {pair_id}', retryable=False, status_code=404)
        _, base, quote, *_ = row
        days = {'1H': 2, '1D': 7, '1W': 14, '1M': 30, '3M': 90, '1Y': 365, 'ALL': 365}.get(
            (period or '1D').upper(), 7
        )
        end = timezone.now().date()
        start = end - timedelta(days=days)
        data = self._get(
            f'/{start.isoformat()}..{end.isoformat()}',
            {'from': base, 'to': quote},
        )
        candles = []
        prices = []
        prev = None
        for day, rates in sorted((data.get('rates') or {}).items()):
            close = _d((rates or {}).get(quote))
            if close <= 0:
                continue
            open_px = prev if prev is not None else close
            high = max(open_px, close)
            low = min(open_px, close)
            ts = int(datetime.fromisoformat(day).replace(tzinfo=dt_timezone.utc).timestamp() * 1000)
            candles.append(
                {'t': ts, 'o': float(open_px), 'h': float(high), 'l': float(low), 'c': float(close), 'v': 0}
            )
            prices.append({'t': ts, 'v': float(close)})
            prev = close
        return {'asset_id': pid, 'pair_id': pid, 'period': period, 'candles': candles, 'prices': prices}

    def get_trending(self) -> list[dict[str, Any]]:
        return self.get_market_overview()['trending']

    def get_top_gainers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        rows = sorted(self.get_pairs(), key=lambda r: r['price_change_percentage_24h'], reverse=True)
        return rows[:limit]

    def get_top_losers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        rows = sorted(self.get_pairs(), key=lambda r: r['price_change_percentage_24h'])
        return rows[:limit]

    def search(self, query: str) -> list[dict[str, Any]]:
        q = (query or '').strip().lower().replace('/', '')
        if not q:
            return []
        return [
            r
            for r in self.get_pairs()
            if q in r['id'] or q in r['symbol'].lower().replace('/', '') or q in r['name'].lower()
        ]
