"""Forex market REST API — Flutter must call these, never external providers."""

from __future__ import annotations

from decimal import Decimal, InvalidOperation

from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from core.utils import camelize

from .health import health_summary
from .models import ForexNotificationPreference, ForexPair, ForexTransaction, ForexWatchlistItem
from .news_service import CATEGORIES, fetch_forex_news
from .paper_trading_service import (
    ForexPaperTradingError,
    get_or_create_wallet,
    place_paper_order,
    portfolio_summary,
)
from .providers.base import ForexProviderError
from .providers.keys import is_secret_error
from .serializers import (
    ForexNotificationPreferenceSerializer,
    ForexTransactionSerializer,
    ForexWatchlistItemSerializer,
)
from .services import ForexService
from .trading_provider import ForexTradingDisabled, get_trading_provider


_GENERIC_FOREX_ERROR = 'Forex market data is temporarily unavailable. Please try again.'


def _client_safe_detail(exc: ForexProviderError) -> str:
    raw = str(exc) or _GENERIC_FOREX_ERROR
    if is_secret_error(raw) or 'http' in raw.lower():
        return _GENERIC_FOREX_ERROR
    return raw[:200]


def _provider_error_response(exc: ForexProviderError):
    return Response(
        {
            'detail': _client_safe_detail(exc),
            'retryable': True,
        },
        status=status.HTTP_503_SERVICE_UNAVAILABLE,
    )


def _jsonable(obj):
    if isinstance(obj, Decimal):
        return str(obj)
    if isinstance(obj, dict):
        return {k: _jsonable(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_jsonable(v) for v in obj]
    return obj


class ForexOverviewView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            return Response(_jsonable(ForexService().get_market_overview()))
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response(
                {'detail': 'Forex market data is temporarily unavailable. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class ForexPairsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        try:
            rows = ForexService().get_pairs()
            return Response({'results': _jsonable(rows)})
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response(
                {'detail': 'Forex market data is temporarily unavailable. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class ForexPairDetailView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pair_id):
        try:
            return Response(_jsonable(ForexService().get_pair(pair_id)))
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response(
                {'detail': 'Forex market data is temporarily unavailable. Please try again.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class ForexChartView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, pair_id):
        period = request.query_params.get('period') or '1D'
        try:
            return Response(_jsonable(ForexService().get_ohlcv(pair_id, period=period)))
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response(
                {'detail': 'Chart is temporarily unavailable for this period.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class ForexSearchView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        q = (request.query_params.get('q') or '').strip()
        if not q:
            return Response({'results': []})
        try:
            return Response({'results': _jsonable(ForexService().search(q))})
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response({'results': []})


class ForexScreenerView(APIView):
    def get(self, request):
        try:
            data = ForexService().screen(
                category=request.query_params.get('category'),
                sort=request.query_params.get('sort') or 'change_desc',
            )
            return Response(_jsonable(data))
        except ForexProviderError as exc:
            return _provider_error_response(exc)


class ForexMoversView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        kind = (request.query_params.get('type') or 'gainers').lower()
        limit = min(int(request.query_params.get('limit') or 20), 50)
        svc = ForexService()
        try:
            if kind == 'losers':
                rows = svc.get_top_losers(limit=limit)
            elif kind == 'trending':
                rows = svc.get_trending()
            else:
                rows = svc.get_top_gainers(limit=limit)
            return Response({'results': _jsonable(rows), 'type': kind})
        except ForexProviderError as exc:
            return _provider_error_response(exc)
        except Exception:
            return Response({'results': [], 'type': kind})


class ForexWatchlistView(APIView):
    def get(self, request):
        items = (
            ForexWatchlistItem.objects.filter(user=request.user)
            .select_related('pair', 'pair__snapshot')
            .all()
        )
        results = []
        for item in items:
            row = ForexWatchlistItemSerializer(item).data
            snap = getattr(item.pair, 'snapshot', None)
            if snap:
                row.update(
                    {
                        'current_price': str(snap.current_price),
                        'price_change_percentage_24h': str(snap.price_change_percentage_24h),
                    }
                )
            results.append(row)
        return Response({'results': results})

    def post(self, request):
        pair_id = (request.data.get('pair_id') or request.data.get('asset_id') or '').strip().lower()
        if not pair_id:
            return Response({'detail': 'pair_id is required.'}, status=400)
        pair = ForexPair.objects.filter(pk=pair_id).first()
        if not pair:
            try:
                data = ForexService().get_pair(pair_id)
                pair, _ = ForexPair.objects.get_or_create(
                    id=data['id'],
                    defaults={
                        'base_currency': (data.get('base_currency') or '')[:8],
                        'quote_currency': (data.get('quote_currency') or '')[:8],
                        'symbol': (data.get('symbol') or pair_id)[:16],
                        'name': (data.get('name') or pair_id)[:120],
                        'category': (data.get('category') or 'Majors')[:32],
                    },
                )
            except ForexProviderError as exc:
                return _provider_error_response(exc)
        item, _ = ForexWatchlistItem.objects.get_or_create(user=request.user, pair=pair)
        return Response(ForexWatchlistItemSerializer(item).data, status=201)


class ForexWatchlistDetailView(APIView):
    def delete(self, request, item_id):
        ForexWatchlistItem.objects.filter(pk=item_id, user=request.user).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ForexNewsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        category = request.query_params.get('category')
        force = (request.query_params.get('refresh') or '') in ('1', 'true', 'yes')
        try:
            articles = fetch_forex_news(category=category, force=force)
            return Response({'results': articles, 'categories': list(CATEGORIES)})
        except Exception:
            return Response({'results': [], 'categories': list(CATEGORIES)})


class ForexPortfolioView(APIView):
    def get(self, request):
        try:
            return Response(_jsonable(portfolio_summary(request.user)))
        except Exception:
            return Response(
                {
                    'environment': 'PAPER TRADING',
                    'wallet_balance': '100000.00',
                    'invested_amount': '0',
                    'current_value': '0',
                    'total_portfolio_value': '100000.00',
                    'profit_loss': '0',
                    'profit_loss_percent': '0',
                    'usd_inr_rate': '83.50',
                    'display_currency': 'USD',
                    'holdings': [],
                    'allocation': [],
                }
            )


class ForexPaperOrderView(APIView):
    def post(self, request):
        pair_id = (request.data.get('pair_id') or request.data.get('asset_id') or '').strip()
        side = request.data.get('side') or 'BUY'
        qty = request.data.get('quantity')
        try:
            result = place_paper_order(
                request.user, pair_id=pair_id, side=side, quantity=Decimal(str(qty))
            )
            return Response(_jsonable(result), status=201)
        except (InvalidOperation, ValueError):
            return Response({'detail': 'Invalid quantity.'}, status=400)
        except ForexPaperTradingError as exc:
            return Response({'detail': str(exc)}, status=400)
        except ForexProviderError as exc:
            return _provider_error_response(exc)


class ForexTransactionsView(APIView):
    def get(self, request):
        qs = ForexTransaction.objects.filter(user=request.user)[:50]
        return Response({'results': ForexTransactionSerializer(qs, many=True).data})


class ForexWalletView(APIView):
    def get(self, request):
        wallet = get_or_create_wallet(request.user)
        return Response(
            {'balance': str(wallet.balance), 'currency': wallet.currency, 'environment': 'PAPER TRADING'}
        )


class ForexHealthView(APIView):
    def get(self, request):
        return Response(health_summary())


class ForexNotificationPreferenceView(APIView):
    def get(self, request):
        pref, _ = ForexNotificationPreference.objects.get_or_create(user=request.user)
        return Response(ForexNotificationPreferenceSerializer(pref).data)

    def put(self, request):
        pref, _ = ForexNotificationPreference.objects.get_or_create(user=request.user)
        ser = ForexNotificationPreferenceSerializer(pref, data=request.data, partial=True)
        ser.is_valid(raise_exception=True)
        ser.save()
        return Response(ser.data)


class ForexLiveTradingStatusView(APIView):
    def get(self, request):
        try:
            get_trading_provider()
            return Response({'enabled': True, 'mode': 'live'})
        except ForexTradingDisabled as exc:
            return Response({'enabled': False, 'mode': 'paper_and_market_data', 'detail': str(exc)})


class ForexOptionChainView(APIView):
    """Paper CE/PE book for major FX pairs — virtual funds only."""

    permission_classes = [AllowAny]

    def get(self, request, pair_id=None):
        from .option_chain import catalog_rows, get_forex_option_chain

        pid = (pair_id or request.query_params.get('underlying') or 'eurusd').strip()
        expiry = request.query_params.get('expiry')
        chain = get_forex_option_chain(pid, expiry=expiry)
        if not chain:
            return Response({'detail': 'No option chain for this pair.'}, status=404)
        return Response(camelize(_jsonable({**chain, 'underlyings': catalog_rows()})))
