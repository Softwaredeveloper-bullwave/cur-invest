"""Crypto market REST API — Flutter must call these, never external providers."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

from django.shortcuts import get_object_or_404
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from .health import health_summary
from .models import (
    CryptoAsset,
    CryptoNotificationPreference,
    CryptoPriceAlert,
    CryptoTransaction,
    CryptoWatchlistItem,
    UserMarketPreference,
)
from .news_service import CATEGORIES, fetch_crypto_news
from .paper_trading_service import (
    CryptoPaperTradingError,
    get_or_create_wallet,
    place_paper_order,
    portfolio_summary,
)
from .providers.base import CryptoProviderError
from .serializers import (
    CryptoNotificationPreferenceSerializer,
    CryptoPriceAlertSerializer,
    CryptoTransactionSerializer,
    CryptoWatchlistItemSerializer,
    UserMarketPreferenceSerializer,
)
from .services import CryptoService
from .trading_provider import CryptoTradingDisabled, get_trading_provider


def _dec_param(value):
    if value in (None, ''):
        return None
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        return None


def _provider_error_response(exc: CryptoProviderError):
    return Response(
        {
            'detail': str(exc) or 'Market data is temporarily unavailable. Please try again.',
            'retryable': exc.retryable,
        },
        status=status.HTTP_503_SERVICE_UNAVAILABLE
        if exc.retryable
        else status.HTTP_400_BAD_REQUEST,
    )


class MarketPreferenceView(APIView):
    def get(self, request):
        pref, _ = UserMarketPreference.objects.get_or_create(user=request.user)
        return Response(UserMarketPreferenceSerializer(pref).data)

    def put(self, request):
        pref, _ = UserMarketPreference.objects.get_or_create(user=request.user)
        data = request.data.copy() if hasattr(request.data, 'copy') else dict(request.data)
        data['has_completed_selection'] = True
        indian = data.get('indian_market_enabled', pref.indian_market_enabled)
        crypto = data.get('crypto_market_enabled', pref.crypto_market_enabled)
        if isinstance(indian, str):
            indian = indian.lower() in ('1', 'true', 'yes')
        if isinstance(crypto, str):
            crypto = crypto.lower() in ('1', 'true', 'yes')
        indian = bool(indian)
        crypto = bool(crypto)
        # One market at a time: if both sent true, prefer active_market / crypto
        requested_active = (data.get('active_market') or '').strip().lower()
        if indian and crypto:
            if requested_active == 'crypto':
                indian, crypto = False, True
            else:
                indian, crypto = True, False
        data['indian_market_enabled'] = indian
        data['crypto_market_enabled'] = crypto
        # Always coerce active_market to the enabled market
        if crypto and not indian:
            data['active_market'] = 'crypto'
        elif indian and not crypto:
            data['active_market'] = 'indian'
        elif requested_active in ('indian', 'crypto'):
            data['active_market'] = requested_active
        else:
            data['active_market'] = 'indian'
        ser = UserMarketPreferenceSerializer(pref, data=data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)

    def patch(self, request):
        return self.put(request)


class CryptoOverviewView(APIView):
    def get(self, request):
        try:
            data = CryptoService().get_market_overview()
            # JSON-serialize Decimals
            return Response(_jsonable(data))
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoAssetsView(APIView):
    def get(self, request):
        page = int(request.query_params.get('page') or 1)
        page_size = int(request.query_params.get('page_size') or 50)
        vs = (request.query_params.get('vs_currency') or 'usd').lower()
        order = request.query_params.get('order') or 'market_cap_desc'
        top = request.query_params.get('top') == '1'
        try:
            svc = CryptoService()
            rows = svc.get_top_assets(vs_currency=vs) if top else svc.get_assets(
                page=page, page_size=page_size, vs_currency=vs, order=order
            )
            return Response({'results': _jsonable(rows), 'page': page, 'page_size': page_size})
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoAssetDetailView(APIView):
    def get(self, request, asset_id):
        vs = (request.query_params.get('vs_currency') or 'usd').lower()
        try:
            data = CryptoService().get_asset(asset_id, vs_currency=vs)
            return Response(_jsonable(data))
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoChartView(APIView):
    def get(self, request, asset_id):
        vs = (request.query_params.get('vs_currency') or 'usd').lower()
        period = request.query_params.get('period') or '1D'
        try:
            data = CryptoService().get_ohlcv(asset_id, vs_currency=vs, days=period)
            return Response(_jsonable(data))
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoSearchView(APIView):
    def get(self, request):
        q = (request.query_params.get('q') or '').strip()
        if not q:
            return Response({'results': []})
        try:
            results = CryptoService().search(q)
            # Enrich top results with live prices when possible
            enriched = []
            svc = CryptoService()
            for item in results[:20]:
                row = dict(item)
                try:
                    quote = svc.get_price(item['id'], vs_currency='usd')
                    row['current_price'] = quote.get('current_price')
                    row['price_change_percentage_24h'] = quote.get('price_change_percentage_24h')
                except Exception:
                    pass
                enriched.append(row)
            return Response({'results': _jsonable(enriched)})
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoScreenerView(APIView):
    def get(self, request):
        try:
            data = CryptoService().screen(
                vs_currency=(request.query_params.get('vs_currency') or 'usd').lower(),
                page=int(request.query_params.get('page') or 1),
                page_size=int(request.query_params.get('page_size') or 50),
                sort=request.query_params.get('sort') or 'market_cap_desc',
                min_price=_dec_param(request.query_params.get('min_price')),
                max_price=_dec_param(request.query_params.get('max_price')),
                min_market_cap=_dec_param(request.query_params.get('min_market_cap')),
                max_market_cap=_dec_param(request.query_params.get('max_market_cap')),
                min_change_24h=_dec_param(request.query_params.get('min_change_24h')),
                max_change_24h=_dec_param(request.query_params.get('max_change_24h')),
                min_volume=_dec_param(request.query_params.get('min_volume')),
            )
            return Response(_jsonable(data))
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoMoversView(APIView):
    def get(self, request):
        kind = (request.query_params.get('type') or 'gainers').lower()
        limit = min(int(request.query_params.get('limit') or 20), 50)
        vs = (request.query_params.get('vs_currency') or 'usd').lower()
        svc = CryptoService()
        try:
            if kind == 'losers':
                rows = svc.get_top_losers(limit=limit, vs_currency=vs)
            elif kind == 'volume':
                rows = svc.get_volume_data(limit=limit, vs_currency=vs)
            elif kind == 'trending':
                rows = svc.get_trending()
            else:
                rows = svc.get_top_gainers(limit=limit, vs_currency=vs)
            return Response({'results': _jsonable(rows), 'type': kind})
        except CryptoProviderError as exc:
            return _provider_error_response(exc)


class CryptoWatchlistView(APIView):
    def get(self, request):
        items = (
            CryptoWatchlistItem.objects.filter(user=request.user)
            .select_related('asset', 'asset__snapshot')
            .all()
        )
        results = []
        for item in items:
            row = CryptoWatchlistItemSerializer(item).data
            snap = getattr(item.asset, 'snapshot', None)
            if snap:
                row.update(
                    {
                        'current_price': str(snap.current_price),
                        'price_change_percentage_24h': str(snap.price_change_percentage_24h),
                        'sparkline_7d': snap.sparkline_7d,
                        'market_status': 'open',
                    }
                )
            results.append(row)
        # Refresh prices in background-ish (sync, cached)
        try:
            ids = [i.asset_id for i in items]
            if ids:
                live = CryptoService().get_assets(ids=ids, page_size=len(ids))
                by_id = {r['id']: r for r in live}
                for row in results:
                    live_row = by_id.get(row['asset_id'])
                    if live_row:
                        row['current_price'] = str(live_row.get('current_price') or '')
                        row['price_change_percentage_24h'] = str(
                            live_row.get('price_change_percentage_24h') or ''
                        )
                        row['sparkline_7d'] = live_row.get('sparkline_7d') or []
        except CryptoProviderError:
            pass
        return Response({'results': results})

    def post(self, request):
        asset_id = (request.data.get('asset_id') or request.data.get('id') or '').strip().lower()
        if not asset_id:
            return Response({'detail': 'asset_id is required.'}, status=400)
        asset = CryptoAsset.objects.filter(pk=asset_id).first()
        if not asset:
            try:
                data = CryptoService().get_asset(asset_id)
                asset, _ = CryptoAsset.objects.get_or_create(
                    id=asset_id,
                    defaults={
                        'symbol': (data.get('symbol') or asset_id)[:32].lower(),
                        'name': (data.get('name') or asset_id)[:120],
                        'image_url': (data.get('image_url') or '')[:500],
                    },
                )
            except CryptoProviderError as exc:
                return _provider_error_response(exc)
        item, created = CryptoWatchlistItem.objects.get_or_create(user=request.user, asset=asset)
        return Response(
            CryptoWatchlistItemSerializer(item).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class CryptoWatchlistDetailView(APIView):
    def delete(self, request, item_id):
        item = get_object_or_404(CryptoWatchlistItem, pk=item_id, user=request.user)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CryptoNewsView(APIView):
    def get(self, request):
        category = request.query_params.get('category')
        force = (request.query_params.get('refresh') or '') in ('1', 'true', 'yes')
        articles = fetch_crypto_news(category=category, force=force)
        return Response({'results': articles, 'categories': list(CATEGORIES)})


class CryptoPortfolioView(APIView):
    def get(self, request):
        return Response(_jsonable(portfolio_summary(request.user)))


class CryptoPaperOrderView(APIView):
    def post(self, request):
        asset_id = (request.data.get('asset_id') or '').strip().lower()
        side = request.data.get('side') or request.data.get('tx_type') or 'BUY'
        qty = request.data.get('quantity')
        try:
            result = place_paper_order(
                request.user, asset_id=asset_id, side=side, quantity=Decimal(str(qty))
            )
            return Response(result, status=status.HTTP_201_CREATED)
        except CryptoPaperTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        except CryptoProviderError as exc:
            return _provider_error_response(exc)
        except (InvalidOperation, TypeError, ValueError):
            return Response({'detail': 'Invalid quantity.'}, status=400)


class CryptoTransactionsView(APIView):
    def get(self, request):
        qs = CryptoTransaction.objects.filter(user=request.user).select_related('asset')[:100]
        return Response({'results': CryptoTransactionSerializer(qs, many=True).data})


class CryptoWalletView(APIView):
    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        return Response(
            {
                'balance': str(wallet.balance),
                'currency': wallet.currency,
                'environment': 'PAPER TRADING',
                'last_refilled_at': wallet.last_refilled_at,
            }
        )


class CryptoHealthView(APIView):
    def get(self, request):
        return Response(health_summary())


class CryptoNotificationPreferenceView(APIView):
    def get(self, request):
        pref, _ = CryptoNotificationPreference.objects.get_or_create(user=request.user)
        return Response(CryptoNotificationPreferenceSerializer(pref).data)

    def put(self, request):
        pref, _ = CryptoNotificationPreference.objects.get_or_create(user=request.user)
        ser = CryptoNotificationPreferenceSerializer(pref, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)


class CryptoPriceAlertsView(APIView):
    def get(self, request):
        qs = CryptoPriceAlert.objects.filter(user=request.user, is_active=True)
        return Response({'results': CryptoPriceAlertSerializer(qs, many=True).data})

    def post(self, request):
        asset_id = (request.data.get('asset_id') or '').strip().lower()
        asset = get_object_or_404(CryptoAsset, pk=asset_id)
        alert = CryptoPriceAlert.objects.create(
            user=request.user,
            asset=asset,
            condition=request.data.get('condition') or 'above',
            target_value=Decimal(str(request.data.get('target_value') or 0)),
        )
        return Response(CryptoPriceAlertSerializer(alert).data, status=201)


class CryptoLiveTradingStatusView(APIView):
    """Explicitly reports that live trading is disabled until compliance is ready."""

    def get(self, request):
        try:
            get_trading_provider().get_account()
            enabled = True
        except CryptoTradingDisabled as exc:
            return Response(
                {
                    'enabled': False,
                    'mode': 'paper_and_market_data',
                    'detail': str(exc),
                }
            )
        return Response({'enabled': enabled, 'mode': 'live'})


def _jsonable(obj):
    if isinstance(obj, Decimal):
        return str(obj)
    if isinstance(obj, dict):
        return {k: _jsonable(v) for k, v in obj.items() if not str(k).startswith('_meta')}
    if isinstance(obj, (list, tuple)):
        return [_jsonable(v) for v in obj]
    return obj
