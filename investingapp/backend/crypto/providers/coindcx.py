"""CoinDCX market-data provider — prices, 24h change, volume, OHLC candles."""

from __future__ import annotations

import logging
import time
from decimal import Decimal, InvalidOperation
from typing import Any

import httpx
from django.conf import settings
from django.core.cache import cache

from .base import BaseCryptoProvider, CryptoProviderError
from .coingecko import CoinGeckoProvider

logger = logging.getLogger('bullwave.crypto')

# App asset id (CoinGecko-style) → CoinDCX market + candle pair
ASSET_MAP = {
    'bitcoin': {'symbol': 'BTC', 'market': 'BTCUSDT', 'pair': 'B-BTC_USDT', 'name': 'Bitcoin'},
    'ethereum': {'symbol': 'ETH', 'market': 'ETHUSDT', 'pair': 'B-ETH_USDT', 'name': 'Ethereum'},
    'tether': {'symbol': 'USDT', 'market': 'USDTINR', 'pair': 'I-USDT_INR', 'name': 'Tether'},
    'binancecoin': {'symbol': 'BNB', 'market': 'BNBUSDT', 'pair': 'B-BNB_USDT', 'name': 'BNB'},
    'solana': {'symbol': 'SOL', 'market': 'SOLUSDT', 'pair': 'B-SOL_USDT', 'name': 'Solana'},
    'ripple': {'symbol': 'XRP', 'market': 'XRPUSDT', 'pair': 'B-XRP_USDT', 'name': 'XRP'},
    'usd-coin': {'symbol': 'USDC', 'market': 'USDCUSDT', 'pair': 'B-USDC_USDT', 'name': 'USD Coin'},
    'dogecoin': {'symbol': 'DOGE', 'market': 'DOGEUSDT', 'pair': 'B-DOGE_USDT', 'name': 'Dogecoin'},
    'cardano': {'symbol': 'ADA', 'market': 'ADAUSDT', 'pair': 'B-ADA_USDT', 'name': 'Cardano'},
    'tron': {'symbol': 'TRX', 'market': 'TRXUSDT', 'pair': 'B-TRX_USDT', 'name': 'TRON'},
    'avalanche-2': {'symbol': 'AVAX', 'market': 'AVAXUSDT', 'pair': 'B-AVAX_USDT', 'name': 'Avalanche'},
    'polkadot': {'symbol': 'DOT', 'market': 'DOTUSDT', 'pair': 'B-DOT_USDT', 'name': 'Polkadot'},
    'chainlink': {'symbol': 'LINK', 'market': 'LINKUSDT', 'pair': 'B-LINK_USDT', 'name': 'Chainlink'},
    'litecoin': {'symbol': 'LTC', 'market': 'LTCUSDT', 'pair': 'B-LTC_USDT', 'name': 'Litecoin'},
    'matic-network': {'symbol': 'MATIC', 'market': 'MATICUSDT', 'pair': 'B-MATIC_USDT', 'name': 'Polygon'},
    'near': {'symbol': 'NEAR', 'market': 'NEARUSDT', 'pair': 'B-NEAR_USDT', 'name': 'NEAR'},
    'hyperliquid': {'symbol': 'HYPE', 'market': 'HYPEUSDT', 'pair': 'B-HYPE_USDT', 'name': 'Hyperliquid'},
    'sui': {'symbol': 'SUI', 'market': 'SUIUSDT', 'pair': 'B-SUI_USDT', 'name': 'Sui'},
    'pepe': {'symbol': 'PEPE', 'market': 'PEPEUSDT', 'pair': 'B-PEPE_USDT', 'name': 'Pepe'},
    'shiba-inu': {'symbol': 'SHIB', 'market': 'SHIBUSDT', 'pair': 'B-SHIB_USDT', 'name': 'Shiba Inu'},
    'uniswap': {'symbol': 'UNI', 'market': 'UNIUSDT', 'pair': 'B-UNI_USDT', 'name': 'Uniswap'},
    'aptos': {'symbol': 'APT', 'market': 'APTUSDT', 'pair': 'B-APT_USDT', 'name': 'Aptos'},
    'stellar': {'symbol': 'XLM', 'market': 'XLMUSDT', 'pair': 'B-XLM_USDT', 'name': 'Stellar'},
}

SYMBOL_TO_ID = {v['symbol']: k for k, v in ASSET_MAP.items()}
MARKET_TO_ID = {v['market']: k for k, v in ASSET_MAP.items()}
NAME_TO_ID = {v['name'].lower(): k for k, v in ASSET_MAP.items()}


def resolve_asset_id(asset_id: str) -> str:
    """Normalize route/user input: solana, SOL, SOLANA, SOLUSDT → bitcoin-style id."""
    raw = (asset_id or '').strip()
    if not raw:
        return ''
    lower = raw.lower()
    if lower in ASSET_MAP:
        return lower
    if lower in NAME_TO_ID:
        return NAME_TO_ID[lower]
    upper = raw.upper()
    if upper in SYMBOL_TO_ID:
        return SYMBOL_TO_ID[upper]
    if upper in MARKET_TO_ID:
        return MARKET_TO_ID[upper]
    if upper.endswith('USDT') and upper in MARKET_TO_ID:
        return MARKET_TO_ID[upper]
    # Strip common suffixes
    for suffix in ('USDT', 'INR', '-USD', '/USD'):
        if upper.endswith(suffix):
            base = upper[: -len(suffix)]
            if base in SYMBOL_TO_ID:
                return SYMBOL_TO_ID[base]
    return lower

# CoinDCX public candles currently accept only: 1m, 15m, 1h, 1d
PERIOD_TO_INTERVAL = {
    '1H': ('1m', 60),
    '1D': ('15m', 96),
    '1W': ('1h', 168),
    '1M': ('1h', 720),
    '3M': ('1d', 90),
    '1Y': ('1d', 365),
    'ALL': ('1d', 500),
}


def _dec(value) -> Decimal | None:
    if value is None or value == '':
        return None
    if isinstance(value, str):
        value = value.replace('$', '').replace(',', '').replace('₹', '').strip()
        if not value:
            return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError, TypeError):
        return None


def _meta_from_market(market: str) -> dict[str, str]:
    market = (market or '').upper()
    aid = MARKET_TO_ID.get(market)
    if aid:
        return {'id': aid, **ASSET_MAP[aid]}
    base = market[:-4] if market.endswith('USDT') else market.replace('INR', '')
    return {
        'id': base.lower(),
        'symbol': base,
        'market': market,
        'pair': f'B-{base}_USDT' if market.endswith('USDT') else f'I-{base}_INR',
        'name': base,
    }


class CoinDCXProvider(BaseCryptoProvider):
    """Primary prices/charts from CoinDCX; market-cap / search enriched via CoinGecko when available."""

    name = 'coindcx'

    def __init__(self):
        self.api_key = (getattr(settings, 'COINDCX_API_KEY', '') or '').strip()
        self.api_secret = (getattr(settings, 'COINDCX_SECRET_KEY', '') or '').strip()
        self.base_url = (
            (getattr(settings, 'COINDCX_API_BASE_URL', '') or '').strip().rstrip('/')
            or 'https://api.coindcx.com'
        )
        self.timeout = float(getattr(settings, 'CRYPTO_API_TIMEOUT', 20) or 20)
        self.cache_seconds = int(getattr(settings, 'CRYPTO_MARKET_CACHE_SECONDS', 60) or 60)
        self._cg = CoinGeckoProvider()

    def _headers(self) -> dict[str, str]:
        return {
            'Accept': 'application/json',
            'User-Agent': 'CapitalBullWave/1.0 (crypto-market-data)',
        }

    def _get(self, path: str, params: dict | None = None, *, cache_key: str | None = None, ttl: int | None = None):
        ttl = ttl if ttl is not None else self.cache_seconds
        if cache_key:
            cached = cache.get(cache_key)
            if cached is not None:
                return cached
        url = f'{self.base_url}{path}'
        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.get(url, params=params or {}, headers=self._headers())
        except httpx.TimeoutException as exc:
            raise CryptoProviderError('Crypto market data timed out.', retryable=True) from exc
        except httpx.HTTPError as exc:
            raise CryptoProviderError('Crypto market data is temporarily unavailable.', retryable=True) from exc

        if response.status_code == 429:
            raise CryptoProviderError('Crypto provider rate limit reached.', retryable=True, status_code=429)
        if response.status_code >= 400:
            raise CryptoProviderError(
                f'CoinDCX error ({response.status_code}).',
                retryable=response.status_code >= 500,
                status_code=response.status_code,
            )
        try:
            data = response.json()
        except ValueError as exc:
            raise CryptoProviderError('Invalid response from CoinDCX.', retryable=True) from exc
        if cache_key:
            cache.set(cache_key, data, ttl)
        return data

    def _tickers(self) -> dict[str, dict]:
        rows = self._get('/exchange/ticker', cache_key='crypto:cdx:ticker', ttl=self.cache_seconds)
        if not isinstance(rows, list):
            return {}
        return {str(r.get('market') or ''): r for r in rows if r.get('market')}

    def _row_from_ticker(self, asset_id: str, ticker: dict, *, vs_currency: str = 'usd') -> dict[str, Any]:
        meta = ASSET_MAP.get(asset_id) or {
            'symbol': (ticker.get('market') or '').replace('USDT', ''),
            'name': ticker.get('market'),
            'market': ticker.get('market'),
            'pair': f"B-{(ticker.get('market') or '').replace('USDT', '')}_USDT",
        }
        price = _dec(ticker.get('last_price')) or Decimal('0')
        chg = _dec(ticker.get('change_24_hour')) or Decimal('0')
        high = _dec(ticker.get('high'))
        low = _dec(ticker.get('low'))
        vol = _dec(ticker.get('volume'))
        return {
            'id': asset_id,
            'symbol': meta['symbol'],
            'name': meta.get('name') or meta['symbol'],
            'image_url': '',
            'current_price': price,
            'price_change_24h': None,
            'price_change_percentage_24h': chg,
            'high_24h': high,
            'low_24h': low,
            'market_cap': None,
            'fully_diluted_valuation': None,
            'total_volume': vol,
            'circulating_supply': None,
            'total_supply': None,
            'max_supply': None,
            'ath': None,
            'atl': None,
            'market_cap_rank': None,
            'sparkline_7d': [],
            'currency': vs_currency,
            'provider': self.name,
            'coindcx_market': meta.get('market') or ticker.get('market'),
        }

    def get_market_overview(self) -> dict[str, Any]:
        # Global mcap / BTC dominance from CoinGecko when possible; live prices from CoinDCX.
        overview: dict[str, Any] = {
            'total_market_cap': None,
            'market_cap_change_percentage_24h': None,
            'btc_dominance': None,
            'total_volume': None,
            'active_cryptocurrencies': None,
            'markets': None,
            'fear_greed': None,
            'trending': [],
            'provider': self.name,
            'stale': False,
        }
        try:
            overview.update(self._cg.get_global_stats())
        except CryptoProviderError:
            logger.warning('CoinGecko global stats unavailable; using CoinDCX prices only')
        try:
            overview['fear_greed'] = self._cg.get_fear_greed()
        except Exception:
            overview['fear_greed'] = None
        try:
            overview['trending'] = self.get_assets(page=1, page_size=10, order='volume_desc')
        except CryptoProviderError:
            logger.warning('CoinDCX tickers unavailable for overview trending')
        if overview['total_market_cap'] is None and not overview['trending']:
            raise CryptoProviderError(
                'Crypto market data is temporarily unavailable.',
                retryable=True,
            )
        return overview

    def get_assets(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        vs_currency: str = 'usd',
        order: str = 'market_cap_desc',
        ids: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        try:
            tickers = self._tickers()
        except CryptoProviderError:
            return self._cg.get_assets(
                page=page, page_size=page_size, vs_currency=vs_currency, order=order, ids=ids
            )

        wanted_ids = ids or list(ASSET_MAP.keys())
        rows: list[dict[str, Any]] = []
        seen_markets: set[str] = set()
        for aid in wanted_ids:
            meta = ASSET_MAP.get(aid)
            if not meta:
                continue
            t = tickers.get(meta['market'])
            if not t:
                continue
            if vs_currency == 'usd' and str(meta['market']).endswith('INR'):
                continue
            rows.append(self._row_from_ticker(aid, t, vs_currency=vs_currency))
            seen_markets.add(meta['market'])

        # When listing the open market (not a fixed id list), include extra USDT pairs
        # so coins like HYPE / PONS still show live CoinDCX prices.
        if not ids:
            extras = [
                t
                for market, t in tickers.items()
                if market.endswith('USDT') and market not in seen_markets
            ]
            extras.sort(key=lambda t: float(t.get('volume') or 0), reverse=True)
            for t in extras[:40]:
                meta = _meta_from_market(str(t.get('market') or ''))
                rows.append(self._row_from_ticker(meta['id'], t, vs_currency=vs_currency))

        # Enrich market caps from CoinGecko (best-effort)
        try:
            cg_ids = [r['id'] for r in rows if r.get('id') in ASSET_MAP]
            if cg_ids:
                cg_rows = self._cg.get_assets(ids=cg_ids, page_size=len(cg_ids) or 1)
                by_id = {r['id']: r for r in cg_rows}
                for r in rows:
                    cg = by_id.get(r['id'])
                    if not cg:
                        continue
                    r['market_cap'] = cg.get('market_cap')
                    r['image_url'] = cg.get('image_url') or ''
                    r['sparkline_7d'] = cg.get('sparkline_7d') or []
                    r['market_cap_rank'] = cg.get('market_cap_rank')
                    r['fully_diluted_valuation'] = cg.get('fully_diluted_valuation')
                    r['ath'] = cg.get('ath')
                    r['atl'] = cg.get('atl')
        except CryptoProviderError:
            pass

        if order == 'volume_desc':
            rows.sort(key=lambda r: float(r.get('total_volume') or 0), reverse=True)
        elif order == 'market_cap_asc':
            rows.sort(key=lambda r: float(r.get('market_cap') or 0))
        else:
            rows.sort(
                key=lambda r: (
                    float(r.get('market_cap') or 0),
                    float(r.get('total_volume') or 0),
                ),
                reverse=True,
            )

        start = max(page - 1, 0) * page_size
        return rows[start : start + page_size]

    def get_asset(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        aid = resolve_asset_id(asset_id)
        meta = ASSET_MAP.get(aid)
        try:
            tickers = self._tickers()
        except CryptoProviderError:
            tickers = {}

        if meta and meta['market'] in tickers:
            row = self._row_from_ticker(aid, tickers[meta['market']], vs_currency=vs_currency)
        elif meta:
            # Ticker feed unavailable — still return a CoinDCX-shaped shell, then enrich.
            row = {
                'id': aid,
                'symbol': meta['symbol'],
                'name': meta.get('name') or meta['symbol'],
                'image_url': '',
                'current_price': Decimal('0'),
                'price_change_24h': None,
                'price_change_percentage_24h': Decimal('0'),
                'high_24h': None,
                'low_24h': None,
                'market_cap': None,
                'fully_diluted_valuation': None,
                'total_volume': None,
                'circulating_supply': None,
                'total_supply': None,
                'max_supply': None,
                'ath': None,
                'atl': None,
                'market_cap_rank': None,
                'sparkline_7d': [],
                'description': '',
                'homepage_url': '',
                'community': {},
                'developer': {},
                'currency': vs_currency,
                'provider': self.name,
            }
        else:
            # Unknown id — try CoinGecko detail, overlay CoinDCX price by symbol if possible
            try:
                row = self._cg.get_asset(aid or asset_id, vs_currency=vs_currency)
            except CryptoProviderError as exc:
                raise CryptoProviderError(f'Asset not found: {asset_id}', retryable=False, status_code=404) from exc
            sym = (row.get('symbol') or '').upper()
            market = f'{sym}USDT'
            if market in tickers:
                overlay = self._row_from_ticker(row['id'], tickers[market], vs_currency=vs_currency)
                row['current_price'] = overlay['current_price']
                row['price_change_percentage_24h'] = overlay['price_change_percentage_24h']
                row['high_24h'] = overlay['high_24h']
                row['low_24h'] = overlay['low_24h']
                row['total_volume'] = overlay['total_volume']
                row['provider'] = self.name
            return row

        try:
            cg = self._cg.get_asset(aid, vs_currency=vs_currency)
            if not row.get('current_price'):
                row['current_price'] = cg.get('current_price') or row.get('current_price')
                row['price_change_percentage_24h'] = (
                    cg.get('price_change_percentage_24h') or row.get('price_change_percentage_24h')
                )
                row['high_24h'] = cg.get('high_24h') or row.get('high_24h')
                row['low_24h'] = cg.get('low_24h') or row.get('low_24h')
                row['total_volume'] = cg.get('total_volume') or row.get('total_volume')
            row['description'] = cg.get('description') or ''
            row['image_url'] = cg.get('image_url') or ''
            row['market_cap'] = cg.get('market_cap')
            row['fully_diluted_valuation'] = cg.get('fully_diluted_valuation')
            row['circulating_supply'] = cg.get('circulating_supply')
            row['total_supply'] = cg.get('total_supply')
            row['max_supply'] = cg.get('max_supply')
            row['ath'] = cg.get('ath')
            row['atl'] = cg.get('atl')
            row['homepage_url'] = cg.get('homepage_url') or ''
            row['community'] = cg.get('community') or {}
            row['developer'] = cg.get('developer') or {}
            row['sparkline_7d'] = cg.get('sparkline_7d') or []
        except CryptoProviderError:
            row.setdefault('description', '')
            if not row.get('current_price'):
                # Last resort: CoinGecko-only quote so detail screen is never blank for mapped assets.
                try:
                    cg = self._cg.get_asset(aid, vs_currency=vs_currency)
                    return cg
                except CryptoProviderError:
                    pass
        return row

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

    def _fetch_public_candles(self, pair: str, interval: str, limit: int) -> list[dict]:
        """CoinDCX candles live on the public host; also try the configured API base."""
        hosts = []
        public = 'https://public.coindcx.com'
        if self.base_url.rstrip('/') not in hosts:
            hosts.append(self.base_url.rstrip('/'))
        if public not in hosts:
            hosts.append(public)
        params = {'pair': pair, 'interval': interval, 'limit': min(int(limit), 1000)}
        last_error: CryptoProviderError | None = None
        for host in hosts:
            cache_key = f'crypto:cdx:candles:{host}:{pair}:{interval}:{limit}'
            cached = cache.get(cache_key)
            if cached is not None:
                return cached if isinstance(cached, list) else []
            try:
                with httpx.Client(timeout=self.timeout) as client:
                    response = client.get(
                        f'{host}/market_data/candles',
                        params=params,
                        headers=self._headers(),
                    )
            except httpx.HTTPError as exc:
                last_error = CryptoProviderError('Crypto market data timed out.', retryable=True)
                logger.debug('CoinDCX candles HTTP error %s %s', host, exc)
                continue
            if response.status_code >= 400:
                last_error = CryptoProviderError(
                    f'CoinDCX error ({response.status_code}).',
                    retryable=response.status_code >= 500,
                    status_code=response.status_code,
                )
                continue
            try:
                payload = response.json()
            except ValueError:
                continue
            rows = payload
            if isinstance(payload, dict):
                rows = payload.get('data') or payload.get('candles') or payload.get('result') or []
            if not isinstance(rows, list) or not rows:
                continue
            cache.set(cache_key, rows, max(self.cache_seconds, 60))
            return rows
        if last_error:
            raise last_error
        return []

    def _candles_payload(self, aid: str, days: str, vs_currency: str, raw: list[dict], limit: int) -> dict[str, Any]:
        candles_raw = sorted(raw, key=lambda c: int(c.get('time') or 0))[-limit:]
        prices = []
        volumes = []
        candles = []
        for c in candles_raw:
            t = int(c.get('time') or 0)
            o = float(c.get('open') or 0)
            h = float(c.get('high') or 0)
            low = float(c.get('low') or 0)
            close = float(c.get('close') or 0)
            vol = float(c.get('volume') or 0)
            if close <= 0 and o <= 0:
                continue
            prices.append({'t': t, 'v': close or o})
            volumes.append({'t': t, 'v': vol})
            candles.append({'t': t, 'o': o, 'h': h, 'l': low, 'c': close or o, 'v': vol})
        return {
            'id': aid,
            'currency': vs_currency,
            'period': days,
            'prices': prices,
            'volumes': volumes,
            'candles': candles,
            'provider': self.name,
        }

    def get_ohlcv(self, asset_id: str, *, vs_currency: str = 'usd', days: str = '1') -> dict[str, Any]:
        aid = resolve_asset_id(asset_id)
        meta = ASSET_MAP.get(aid)
        if not meta:
            tickers = {}
            try:
                tickers = self._tickers()
            except CryptoProviderError:
                pass
            market = f'{aid.upper()}USDT'
            if market in tickers:
                meta = _meta_from_market(market)
            else:
                return self._cg.get_ohlcv(aid or asset_id, vs_currency=vs_currency, days=days)

        period = (days or '1D').upper()
        interval, limit = PERIOD_TO_INTERVAL.get(period, ('1h', 168))
        # CoinDCX public candles only accept 1m / 15m / 1h / 1d.
        allowed = {'1m', '15m', '1h', '1d'}
        if interval not in allowed:
            interval = '1h' if period in ('1W', '1M') else '1d'
        try_order = [interval]
        for extra in ('1h', '1d', '15m', '1m'):
            if extra not in try_order:
                try_order.append(extra)

        last_error: Exception | None = None
        for iv in try_order:
            try:
                raw = self._fetch_public_candles(meta['pair'], iv, limit)
            except CryptoProviderError as exc:
                last_error = exc
                continue
            payload = self._candles_payload(aid, days, vs_currency, raw, limit)
            if payload['candles']:
                return payload

        try:
            return self._cg.get_ohlcv(aid, vs_currency=vs_currency, days=days)
        except CryptoProviderError:
            if last_error:
                logger.warning('Chart fallback failed for %s', aid)
            # Last resort: 2 synthetic candles from the live ticker so the UI is never blank.
            try:
                tickers = self._tickers()
                t = tickers.get(meta['market']) or {}
                close = float(t.get('last_price') or 0)
                high = float(t.get('high') or close)
                low = float(t.get('low') or close)
                if close > 0:
                    now_ms = int(time.time() * 1000)
                    prev = low if low > 0 else close
                    return {
                        'id': aid,
                        'currency': vs_currency,
                        'period': days,
                        'prices': [{'t': now_ms - 3600000, 'v': prev}, {'t': now_ms, 'v': close}],
                        'volumes': [],
                        'candles': [
                            {'t': now_ms - 3600000, 'o': prev, 'h': high, 'l': low, 'c': prev, 'v': 0},
                            {'t': now_ms, 'o': prev, 'h': high, 'l': low, 'c': close, 'v': 0},
                        ],
                        'provider': self.name,
                    }
            except Exception:
                pass
            raise

    def get_market_stats(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        return self.get_asset(asset_id, vs_currency=vs_currency)

    def get_trending(self) -> list[dict[str, Any]]:
        return self.get_assets(page=1, page_size=10, order='volume_desc')

    def get_top_gainers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        rows = self.get_assets(page=1, page_size=50, vs_currency=vs_currency)
        rows.sort(key=lambda r: float(r.get('price_change_percentage_24h') or 0), reverse=True)
        return rows[:limit]

    def get_top_losers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        rows = self.get_assets(page=1, page_size=50, vs_currency=vs_currency)
        rows.sort(key=lambda r: float(r.get('price_change_percentage_24h') or 0))
        return rows[:limit]

    def get_volume_data(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        return self.get_assets(page=1, page_size=limit, vs_currency=vs_currency, order='volume_desc')

    def search(self, query: str) -> list[dict[str, Any]]:
        q = (query or '').strip().lower()
        if not q:
            return []
        # Prefer CoinGecko search for discovery, then overlay CoinDCX prices
        try:
            results = self._cg.search(q)
        except CryptoProviderError:
            results = []
            for aid, meta in ASSET_MAP.items():
                if q in aid or q in meta['symbol'].lower() or q in meta['name'].lower():
                    results.append(
                        {
                            'id': aid,
                            'symbol': meta['symbol'],
                            'name': meta['name'],
                            'image_url': '',
                            'market_cap_rank': None,
                        }
                    )
        tickers = self._tickers()
        enriched = []
        for item in results[:40]:
            row = dict(item)
            sym = (row.get('symbol') or '').upper()
            market = f'{sym}USDT'
            t = tickers.get(market)
            if t:
                row['current_price'] = _dec(t.get('last_price'))
                row['price_change_percentage_24h'] = _dec(t.get('change_24_hour'))
                row['total_volume'] = _dec(t.get('volume'))
            enriched.append(row)
        return enriched

    def get_fear_greed(self) -> dict[str, Any] | None:
        return self._cg.get_fear_greed()
