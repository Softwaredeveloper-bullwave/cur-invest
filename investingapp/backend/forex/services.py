"""ForexService — facade over Twelve Data → Alpha Vantage → ECB Frankfurter."""

from __future__ import annotations

from decimal import Decimal
from typing import Any
import logging

from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from .health import record_provider_call
from .models import ForexMarketSnapshot, ForexPair
from .pairs import FOREX_PAIRS, normalize_pair_id, pair_symbol
from .providers.alphavantage import AlphaVantageForexProvider
from .providers.base import BaseForexProvider, ForexProviderError
from .providers.frankfurter import FrankfurterProvider
from .providers.keys import alphavantage_forex_key, twelve_data_api_key
from .providers.twelvedata import TwelveDataProvider

logger = logging.getLogger('bullwave.forex')


def _price(row: dict[str, Any]) -> Decimal:
    try:
        return Decimal(str(row.get('current_price') or 0))
    except Exception:
        return Decimal('0')


def _has_priced_rows(rows: Any) -> bool:
    if not isinstance(rows, list):
        return False
    return any(_price(r) > 0 for r in rows if isinstance(r, dict))


def _ohlcv_usable(data: Any) -> bool:
    return isinstance(data, dict) and bool(data.get('candles') or data.get('prices'))


def forex_provider_chain() -> list[BaseForexProvider]:
    name = (getattr(settings, 'FOREX_DATA_PROVIDER', 'auto') or 'auto').lower().strip()
    if name in ('frankfurter', 'ecb'):
        return [FrankfurterProvider()]

    chain: list[BaseForexProvider] = []
    use_twelve = name in ('auto', '', 'twelvedata', 'twelve', 'generic')
    use_av = name in ('auto', '', 'alphavantage', 'alpha')
    if use_twelve and twelve_data_api_key():
        chain.append(TwelveDataProvider())
    if use_av and alphavantage_forex_key():
        chain.append(AlphaVantageForexProvider())
    chain.append(FrankfurterProvider())
    return chain


def active_forex_provider() -> BaseForexProvider:
    return forex_provider_chain()[0]


class ForexService:
    def __init__(
        self,
        provider: BaseForexProvider | None = None,
        *,
        chain: list[BaseForexProvider] | None = None,
    ):
        if chain is not None:
            self._chain = chain
        elif provider is not None:
            self._chain = [provider]
        else:
            self._chain = forex_provider_chain()
        self.provider = self._chain[0]

    def _invoke(self, provider: BaseForexProvider, service: str, endpoint: str, fn):
        try:
            started = timezone.now()
            result = fn()
            elapsed = int((timezone.now() - started).total_seconds() * 1000)
            record_provider_call(
                service=service,
                endpoint=endpoint,
                success=True,
                response_ms=elapsed,
                provider_name=provider.name,
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
                provider_name=provider.name,
            )
            logger.warning('Forex %s failed via %s: %s', endpoint, provider.name, str(exc)[:180])
            raise

    def _call(self, service: str, endpoint: str, fn):
        """Legacy single-provider call — used when a specific provider was injected."""
        return self._invoke(self.provider, service, endpoint, fn)

    def _try_chain(self, service: str, endpoint: str, method: str, **kwargs):
        last_exc: ForexProviderError | None = None
        for provider in self._chain:
            fn = getattr(provider, method)
            try:
                result = self._invoke(provider, service, endpoint, lambda: fn(**kwargs) if kwargs else fn())
            except ForexProviderError as exc:
                last_exc = exc
                continue
            if method in ('get_pairs', 'get_trending', 'get_top_gainers', 'get_top_losers', 'search'):
                if not _has_priced_rows(result):
                    last_exc = ForexProviderError(f'{provider.name} returned no forex prices.')
                    continue
            elif method == 'get_pair' or method == 'get_price':
                if not isinstance(result, dict) or _price(result) <= 0:
                    last_exc = ForexProviderError(f'{provider.name} returned no forex price.')
                    continue
            elif method == 'get_ohlcv':
                if not _ohlcv_usable(result):
                    last_exc = ForexProviderError(f'{provider.name} returned no candles.')
                    continue
            elif method == 'get_market_overview':
                majors = (result or {}).get('majors') if isinstance(result, dict) else None
                trending = (result or {}).get('trending') if isinstance(result, dict) else None
                if not _has_priced_rows(majors or trending or []):
                    last_exc = ForexProviderError(f'{provider.name} returned an empty overview.')
                    continue
            self.provider = provider
            return result
        raise last_exc or ForexProviderError(
            'Forex market data is temporarily unavailable. Please try again.'
        )

    def _merge_pair_lists(self, paid: list[dict[str, Any]], catalog: list[dict[str, Any]]) -> list[dict[str, Any]]:
        merged = {row['id']: row for row in catalog if row.get('id')}
        for row in paid:
            pid = row.get('id')
            if pid and _price(row) > 0:
                merged[pid] = {**merged.get(pid, {}), **row}
        return list(merged.values()) or paid or catalog

    def _pairs_with_failover(self, **kwargs) -> list[dict[str, Any]]:
        paid_rows: list[dict[str, Any]] | None = None
        last_exc: ForexProviderError | None = None
        catalog: list[dict[str, Any]] | None = None
        for provider in self._chain:
            fn = provider.get_pairs
            try:
                rows = self._invoke(
                    provider,
                    'market_data',
                    'pairs',
                    lambda p=provider, k=kwargs: p.get_pairs(**k),
                )
            except ForexProviderError as exc:
                last_exc = exc
                continue
            if not _has_priced_rows(rows):
                last_exc = ForexProviderError(f'{provider.name} returned no forex prices.')
                continue
            if provider.name == 'frankfurter':
                catalog = rows
                self.provider = provider
                continue
            paid_rows = rows
            self.provider = provider
            if sum(1 for row in rows if _price(row) > 0) >= 10:
                break
        if paid_rows and catalog:
            return self._merge_pair_lists(paid_rows, catalog)
        if paid_rows:
            return paid_rows
        if catalog:
            return catalog
        raise last_exc or ForexProviderError(
            'Forex market data is temporarily unavailable. Please try again.'
        )

    def _overview_from_pairs(self, pairs: list[dict[str, Any]]) -> dict[str, Any]:
        gainers = sorted(
            pairs,
            key=lambda r: r.get('price_change_percentage_24h') or Decimal('0'),
            reverse=True,
        )
        return {
            'total_pairs': len(pairs),
            'majors': [r for r in pairs if r.get('category') == 'Majors'],
            'trending': gainers[:5],
            'top_gainers': gainers[:5],
            'top_losers': list(reversed(gainers[-5:])),
            'provider': self.provider.name,
        }

    def get_market_overview(self) -> dict[str, Any]:
        cache_key = 'forex:svc:overview'
        cached = cache.get(cache_key)
        try:
            pairs = self.get_pairs()
            data = self._overview_from_pairs(pairs)
            cache.set(cache_key, data, getattr(settings, 'FOREX_MARKET_CACHE_SECONDS', 60))
            return data
        except ForexProviderError:
            if cached:
                return {**cached, 'stale': True}
            raise

    def get_pairs(self, **kwargs) -> list[dict[str, Any]]:
        rows = self._pairs_with_failover(**kwargs)
        self._upsert_pairs(rows)
        return rows

    def get_pair(self, pair_id: str) -> dict[str, Any]:
        data = self._try_chain(
            'market_data',
            f'pair:{pair_id}',
            'get_pair',
            pair_id=normalize_pair_id(pair_id),
        )
        self._upsert_pairs([data])
        return data

    def get_price(self, pair_id: str) -> dict[str, Any]:
        return self._try_chain(
            'market_data',
            f'price:{pair_id}',
            'get_price',
            pair_id=normalize_pair_id(pair_id),
        )

    def get_ohlcv(self, pair_id: str, *, period: str = '1D') -> dict[str, Any]:
        return self._try_chain(
            'market_data',
            f'ohlcv:{pair_id}',
            'get_ohlcv',
            pair_id=normalize_pair_id(pair_id),
            period=period,
        )

    def get_trending(self) -> list[dict[str, Any]]:
        return self.get_market_overview().get('trending') or []

    def get_top_gainers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        rows = sorted(self.get_pairs(), key=lambda r: r.get('price_change_percentage_24h') or Decimal('0'), reverse=True)
        return rows[:limit]

    def get_top_losers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        rows = sorted(self.get_pairs(), key=lambda r: r.get('price_change_percentage_24h') or Decimal('0'))
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

    def screen(self, *, category: str | None = None, sort: str = 'change_desc') -> dict[str, Any]:
        rows = self.get_pairs()
        if category and category.lower() not in ('all', '*'):
            rows = [r for r in rows if (r.get('category') or '').lower() == category.lower()]
        reverse = not sort.endswith('_asc')
        key = 'price_change_percentage_24h' if 'change' in sort else 'current_price'
        rows = sorted(rows, key=lambda r: r.get(key) or Decimal('0'), reverse=reverse)
        return {'results': rows, 'count': len(rows)}

    def _upsert_pairs(self, rows: list[dict[str, Any]]) -> None:
        try:
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
        except Exception:
            logger.debug('Forex pair persist skipped', exc_info=True)


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
