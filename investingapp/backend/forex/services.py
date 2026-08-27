"""ForexService — facade over BaseForexProvider. Flutter never calls providers."""

from __future__ import annotations

from decimal import Decimal
from typing import Any

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from .health import record_provider_call
from .models import ForexMarketSnapshot, ForexPair
from .pairs import FOREX_PAIRS, normalize_pair_id, pair_symbol
from .providers.base import BaseForexProvider, ForexProviderError
from .providers.frankfurter import FrankfurterProvider
from .providers.twelvedata import TwelveDataProvider


def active_forex_provider() -> BaseForexProvider:
    name = (getattr(settings, 'FOREX_DATA_PROVIDER', 'auto') or 'auto').lower().strip()
    has_key = bool((getattr(settings, 'FOREX_API_KEY', '') or '').strip())
    if name in ('twelvedata', 'twelve', 'generic') or (name in ('auto', '') and has_key):
        return TwelveDataProvider()
    return FrankfurterProvider()


class ForexService:
    def __init__(self, provider: BaseForexProvider | None = None):
        self.provider = provider or active_forex_provider()

    def _call(self, service: str, endpoint: str, fn):
        try:
            started = timezone.now()
            result = fn()
            elapsed = int((timezone.now() - started).total_seconds() * 1000)
            record_provider_call(
                service=service,
                endpoint=endpoint,
                success=True,
                response_ms=elapsed,
                provider_name=self.provider.name,
            )
            return result
        except ForexProviderError as exc:
            record_provider_call(
                service=service,
                endpoint=endpoint,
                success=False,
                status_code=exc.status_code,
                error_type=type(exc).__name__,
                error_message=str(exc)[:400],
                provider_name=self.provider.name,
            )
            raise

    def get_market_overview(self) -> dict[str, Any]:
        cache_key = 'forex:svc:overview'
        cached = cache.get(cache_key)
        try:
            data = self._call('market_data', 'overview', self.provider.get_market_overview)
            cache.set(cache_key, data, getattr(settings, 'FOREX_MARKET_CACHE_SECONDS', 60))
            self._upsert_pairs(data.get('majors') or data.get('trending') or [])
            return data
        except ForexProviderError:
            if cached:
                return {**cached, 'stale': True}
            raise

    def get_pairs(self, **kwargs) -> list[dict[str, Any]]:
        rows = self._call('market_data', 'pairs', lambda: self.provider.get_pairs(**kwargs))
        self._upsert_pairs(rows)
        return rows

    def get_pair(self, pair_id: str) -> dict[str, Any]:
        data = self._call(
            'market_data',
            f'pair:{pair_id}',
            lambda: self.provider.get_pair(normalize_pair_id(pair_id)),
        )
        self._upsert_pairs([data])
        return data

    def get_price(self, pair_id: str) -> dict[str, Any]:
        return self._call(
            'market_data',
            f'price:{pair_id}',
            lambda: self.provider.get_price(normalize_pair_id(pair_id)),
        )

    def get_ohlcv(self, pair_id: str, *, period: str = '1D') -> dict[str, Any]:
        return self._call(
            'market_data',
            f'ohlcv:{pair_id}',
            lambda: self.provider.get_ohlcv(normalize_pair_id(pair_id), period=period),
        )

    def get_trending(self) -> list[dict[str, Any]]:
        return self._call('market_data', 'trending', self.provider.get_trending)

    def get_top_gainers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        return self._call('market_data', 'gainers', lambda: self.provider.get_top_gainers(limit=limit))

    def get_top_losers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        return self._call('market_data', 'losers', lambda: self.provider.get_top_losers(limit=limit))

    def search(self, query: str) -> list[dict[str, Any]]:
        return self._call('market_data', 'search', lambda: self.provider.search(query))

    def screen(self, *, category: str | None = None, sort: str = 'change_desc') -> dict[str, Any]:
        rows = self.get_pairs()
        if category and category.lower() not in ('all', '*'):
            rows = [r for r in rows if (r.get('category') or '').lower() == category.lower()]
        reverse = not sort.endswith('_asc')
        key = 'price_change_percentage_24h' if 'change' in sort else 'current_price'
        rows = sorted(rows, key=lambda r: r.get(key) or Decimal('0'), reverse=reverse)
        return {'results': rows, 'count': len(rows)}

    def _upsert_pairs(self, rows: list[dict[str, Any]]) -> None:
        for row in rows:
            pid = normalize_pair_id(row.get('id') or '')
            if not pid:
                continue
            pair, _ = ForexPair.objects.update_or_create(
                id=pid,
                defaults={
                    'base_currency': (row.get('base_currency') or '')[:8],
                    'quote_currency': (row.get('quote_currency') or '')[:8],
                    'symbol': (row.get('symbol') or pair_symbol(pid))[:16],
                    'name': (row.get('name') or pid)[:120],
                    'category': (row.get('category') or 'Majors')[:32],
                    'is_active': True,
                },
            )
            ForexMarketSnapshot.objects.update_or_create(
                pair=pair,
                defaults={
                    'current_price': Decimal(str(row.get('current_price') or 0)),
                    'price_change_24h': Decimal(str(row.get('price_change_24h') or 0)),
                    'price_change_percentage_24h': Decimal(
                        str(row.get('price_change_percentage_24h') or 0)
                    ),
                    'high_24h': Decimal(str(row.get('high_24h') or 0)) if row.get('high_24h') else None,
                    'low_24h': Decimal(str(row.get('low_24h') or 0)) if row.get('low_24h') else None,
                    'sparkline_7d': row.get('sparkline_7d') or [],
                    'provider': self.provider.name,
                    'fetched_at': timezone.now(),
                },
            )


def seed_pairs() -> None:
    for pid, base, quote, name, category in FOREX_PAIRS:
        ForexPair.objects.get_or_create(
            id=pid,
            defaults={
                'base_currency': base,
                'quote_currency': quote,
                'symbol': f'{base}/{quote}',
                'name': name,
                'category': category,
            },
        )
