"""CryptoService — application facade over BaseCryptoProvider implementations."""

from __future__ import annotations

import logging
from decimal import Decimal
from typing import Any

from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.utils import timezone

from .health import record_provider_call
from .models import CryptoAsset, CryptoMarketSnapshot
from .providers.base import BaseCryptoProvider, CryptoProviderError
from .providers.coingecko import CoinGeckoProvider

logger = logging.getLogger('bullwave.crypto')

TOP_IDS = (
    'bitcoin',
    'ethereum',
    'tether',
    'binancecoin',
    'solana',
    'ripple',
    'usd-coin',
    'dogecoin',
    'cardano',
    'tron',
)


def active_crypto_provider() -> BaseCryptoProvider:
    name = (getattr(settings, 'CRYPTO_DATA_PROVIDER', 'coingecko') or 'coingecko').lower().strip()
    if name in ('coingecko', 'auto', ''):
        return CoinGeckoProvider()
    # Future: CryptoProviderB
    return CoinGeckoProvider()


def provider_label() -> str:
    return active_crypto_provider().name


class CryptoService:
    """Stable interface used by views/AI — never call providers from Flutter."""

    def __init__(self, provider: BaseCryptoProvider | None = None):
        self.provider = provider or active_crypto_provider()

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
        except CryptoProviderError as exc:
            record_provider_call(
                service=service,
                endpoint=endpoint,
                success=False,
                status_code=exc.status_code,
                error_type=type(exc).__name__,
                error_message=str(exc)[:400],
                provider_name=self.provider.name,
            )
            # Serve stale snapshot cache when available
            raise

    def get_market_overview(self) -> dict[str, Any]:
        cache_key = 'crypto:svc:overview'
        cached = cache.get(cache_key)
        try:
            data = self._call('market_data', 'overview', self.provider.get_market_overview)
            cache.set(cache_key, data, getattr(settings, 'CRYPTO_MARKET_CACHE_SECONDS', 60))
            return data
        except CryptoProviderError:
            if cached:
                return {**cached, 'stale': True}
            raise

    def get_assets(self, **kwargs) -> list[dict[str, Any]]:
        rows = self._call('market_data', 'assets', lambda: self.provider.get_assets(**kwargs))
        self._upsert_assets(rows)
        return rows

    def get_top_assets(self, *, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        return self.get_assets(page=1, page_size=20, vs_currency=vs_currency, ids=list(TOP_IDS))

    def get_asset(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        data = self._call(
            'market_data',
            f'asset:{asset_id}',
            lambda: self.provider.get_asset(asset_id, vs_currency=vs_currency),
        )
        self._upsert_assets([data])
        return data

    def get_price(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        return self._call(
            'market_data',
            f'price:{asset_id}',
            lambda: self.provider.get_price(asset_id, vs_currency=vs_currency),
        )

    def get_ohlcv(self, asset_id: str, **kwargs) -> dict[str, Any]:
        return self._call(
            'market_data',
            f'ohlcv:{asset_id}',
            lambda: self.provider.get_ohlcv(asset_id, **kwargs),
        )

    def get_trending(self) -> list[dict[str, Any]]:
        return self._call('market_data', 'trending', self.provider.get_trending)

    def get_top_gainers(self, **kwargs) -> list[dict[str, Any]]:
        return self._call('market_data', 'gainers', lambda: self.provider.get_top_gainers(**kwargs))

    def get_top_losers(self, **kwargs) -> list[dict[str, Any]]:
        return self._call('market_data', 'losers', lambda: self.provider.get_top_losers(**kwargs))

    def get_volume_data(self, **kwargs) -> list[dict[str, Any]]:
        return self._call('market_data', 'volume', lambda: self.provider.get_volume_data(**kwargs))

    def search(self, query: str) -> list[dict[str, Any]]:
        return self._call('market_data', 'search', lambda: self.provider.search(query))

    def screen(
        self,
        *,
        vs_currency: str = 'usd',
        page: int = 1,
        page_size: int = 50,
        sort: str = 'market_cap_desc',
        min_price: Decimal | None = None,
        max_price: Decimal | None = None,
        min_market_cap: Decimal | None = None,
        max_market_cap: Decimal | None = None,
        min_change_24h: Decimal | None = None,
        max_change_24h: Decimal | None = None,
        min_volume: Decimal | None = None,
    ) -> dict[str, Any]:
        order_map = {
            'market_cap_desc': 'market_cap_desc',
            'market_cap_asc': 'market_cap_asc',
            'volume_desc': 'volume_desc',
            'gainers': 'market_cap_desc',
            'losers': 'market_cap_desc',
            'trending': 'market_cap_desc',
        }
        order = order_map.get(sort, 'market_cap_desc')
        rows = self.get_assets(page=page, page_size=min(page_size, 100), vs_currency=vs_currency, order=order)

        def _ok(row):
            price = row.get('current_price') or Decimal('0')
            mcap = row.get('market_cap') or Decimal('0')
            chg = row.get('price_change_percentage_24h') or Decimal('0')
            vol = row.get('total_volume') or Decimal('0')
            if min_price is not None and price < min_price:
                return False
            if max_price is not None and price > max_price:
                return False
            if min_market_cap is not None and mcap < min_market_cap:
                return False
            if max_market_cap is not None and mcap > max_market_cap:
                return False
            if min_change_24h is not None and chg < min_change_24h:
                return False
            if max_change_24h is not None and chg > max_change_24h:
                return False
            if min_volume is not None and vol < min_volume:
                return False
            return True

        filtered = [r for r in rows if _ok(r)]
        if sort == 'gainers':
            filtered.sort(key=lambda r: float(r.get('price_change_percentage_24h') or 0), reverse=True)
        elif sort == 'losers':
            filtered.sort(key=lambda r: float(r.get('price_change_percentage_24h') or 0))
        elif sort == 'trending':
            trending_ids = {t.get('id') for t in self.get_trending()}
            filtered.sort(key=lambda r: (0 if r.get('id') in trending_ids else 1, r.get('market_cap_rank') or 9999))

        return {
            'results': filtered,
            'page': page,
            'page_size': page_size,
            'count': len(filtered),
            'provider': self.provider.name,
        }

    def _upsert_assets(self, rows: list[dict[str, Any]]) -> None:
        now = timezone.now()
        for row in rows:
            aid = (row.get('id') or '').strip().lower()
            if not aid:
                continue
            try:
                with transaction.atomic():
                    asset, _ = CryptoAsset.objects.update_or_create(
                        id=aid,
                        defaults={
                            'symbol': (row.get('symbol') or aid)[:32].lower(),
                            'name': (row.get('name') or aid)[:120],
                            'image_url': (row.get('image_url') or '')[:500],
                            'market_cap_rank': row.get('market_cap_rank'),
                            'about': (row.get('description') or '')[:5000] if row.get('description') else '',
                            'homepage_url': (row.get('homepage_url') or '')[:500],
                            'is_active': True,
                        },
                    )
                    if row.get('current_price') is not None:
                        CryptoMarketSnapshot.objects.update_or_create(
                            asset=asset,
                            defaults={
                                'current_price': row.get('current_price') or Decimal('0'),
                                'price_change_24h': row.get('price_change_24h') or Decimal('0'),
                                'price_change_percentage_24h': row.get('price_change_percentage_24h')
                                or Decimal('0'),
                                'high_24h': row.get('high_24h'),
                                'low_24h': row.get('low_24h'),
                                'market_cap': row.get('market_cap'),
                                'fully_diluted_valuation': row.get('fully_diluted_valuation'),
                                'total_volume': row.get('total_volume'),
                                'circulating_supply': row.get('circulating_supply'),
                                'total_supply': row.get('total_supply'),
                                'max_supply': row.get('max_supply'),
                                'ath': row.get('ath'),
                                'atl': row.get('atl'),
                                'currency': row.get('currency') or 'usd',
                                'sparkline_7d': row.get('sparkline_7d') or [],
                                'provider': self.provider.name,
                                'fetched_at': now,
                            },
                        )
            except Exception:
                logger.exception('Failed to upsert crypto asset %s', aid)
