"""Crypto paper trading — VIRTUAL FUNDS ONLY. No real exchange execution."""

from __future__ import annotations

from decimal import Decimal, ROUND_DOWN

from django.db import transaction
from django.utils import timezone

from .models import (
    CryptoAsset,
    CryptoHolding,
    CryptoPracticeWallet,
    CryptoTransaction,
)
from .services import CryptoService

STARTING_BALANCE = Decimal('100000.00')
REFILL_THRESHOLD = Decimal('10000.00')


class CryptoPaperTradingError(Exception):
    pass


def get_or_create_wallet(user) -> CryptoPracticeWallet:
    wallet, _ = CryptoPracticeWallet.objects.get_or_create(
        user=user,
        defaults={'balance': STARTING_BALANCE},
    )
    if wallet.balance < REFILL_THRESHOLD:
        wallet.balance = STARTING_BALANCE
        wallet.last_refilled_at = timezone.now()
        wallet.save(update_fields=['balance', 'last_refilled_at', 'updated_at'])
    return wallet


def _inr_price(asset_id: str) -> Decimal:
    """Fetch USD price and convert to INR using the live USD/INR rate."""
    svc = CryptoService()
    quote = svc.get_price(asset_id, vs_currency='usd')
    usd = quote.get('current_price') or Decimal('0')
    return (Decimal(str(usd)) * _cached_usd_inr()).quantize(Decimal('0.01'))


@transaction.atomic
def place_paper_order(user, *, asset_id: str, side: str, quantity: Decimal) -> dict:
    side = (side or '').upper().strip()
    if side not in ('BUY', 'SELL'):
        raise CryptoPaperTradingError('Side must be BUY or SELL.')
    qty = Decimal(str(quantity))
    if qty <= 0:
        raise CryptoPaperTradingError('Quantity must be positive.')

    aid = (asset_id or '').strip().lower()
    asset = CryptoAsset.objects.filter(pk=aid).first()
    if not asset:
        # Ensure asset exists via market fetch
        data = CryptoService().get_asset(aid)
        asset, _ = CryptoAsset.objects.get_or_create(
            id=aid,
            defaults={
                'symbol': (data.get('symbol') or aid)[:32].lower(),
                'name': (data.get('name') or aid)[:120],
                'image_url': (data.get('image_url') or '')[:500],
            },
        )

    price = _inr_price(aid)
    if price <= 0:
        raise CryptoPaperTradingError('Unable to fetch a valid market price.')

    total = (price * qty).quantize(Decimal('0.01'), rounding=ROUND_DOWN)
    wallet = get_or_create_wallet(user)
    wallet = CryptoPracticeWallet.objects.select_for_update().get(pk=wallet.pk)

    if side == 'BUY':
        if wallet.balance < total:
            raise CryptoPaperTradingError('Insufficient paper trading balance.')
        wallet.balance -= total
        wallet.save(update_fields=['balance', 'updated_at'])
        holding, _ = CryptoHolding.objects.select_for_update().get_or_create(
            user=user, asset=asset, defaults={'quantity': Decimal('0'), 'avg_price': Decimal('0')}
        )
        new_qty = holding.quantity + qty
        if new_qty > 0:
            holding.avg_price = (
                (holding.avg_price * holding.quantity) + (price * qty)
            ) / new_qty
        holding.quantity = new_qty
        holding.save()
    else:
        holding = (
            CryptoHolding.objects.select_for_update()
            .filter(user=user, asset=asset)
            .first()
        )
        if not holding or holding.quantity < qty:
            raise CryptoPaperTradingError('Insufficient holding quantity.')
        holding.quantity -= qty
        if holding.quantity == 0:
            holding.avg_price = Decimal('0')
        holding.save()
        wallet.balance += total
        wallet.save(update_fields=['balance', 'updated_at'])

    tx = CryptoTransaction.objects.create(
        user=user,
        asset=asset,
        tx_type=CryptoTransaction.TxType.BUY if side == 'BUY' else CryptoTransaction.TxType.SELL,
        quantity=qty,
        price=price,
        total_value=total,
        fees=Decimal('0'),
        currency='INR',
        exchange='PAPER',
        status=CryptoTransaction.Status.COMPLETED,
        is_paper=True,
        notes='PAPER TRADING',
    )
    return {
        'id': str(tx.id),
        'asset_id': asset.id,
        'symbol': asset.symbol.upper(),
        'side': side,
        'quantity': str(qty),
        'price': str(price),
        'total_value': str(total),
        'status': tx.status,
        'is_paper': True,
        'environment': 'PAPER TRADING',
        'wallet_balance': str(wallet.balance),
    }


def portfolio_summary(user) -> dict:
    wallet = get_or_create_wallet(user)
    holdings = list(
        CryptoHolding.objects.filter(user=user, quantity__gt=0).select_related('asset')
    )
    svc = CryptoService()
    items = []
    invested = Decimal('0')
    current = Decimal('0')
    for h in holdings:
        try:
            px = _inr_price(h.asset_id)
        except Exception:
            px = h.avg_price
        value = (px * h.quantity).quantize(Decimal('0.01'))
        cost = (h.avg_price * h.quantity).quantize(Decimal('0.01'))
        pnl = value - cost
        pnl_pct = (pnl / cost * 100) if cost else Decimal('0')
        invested += cost
        current += value
        items.append(
            {
                'asset_id': h.asset_id,
                'symbol': h.asset.symbol.upper(),
                'name': h.asset.name,
                'image_url': h.asset.image_url,
                'quantity': str(h.quantity),
                'avg_price': str(h.avg_price),
                'current_price': str(px),
                'invested': str(cost),
                'current_value': str(value),
                'unrealized_pnl': str(pnl),
                'unrealized_pnl_percent': str(pnl_pct.quantize(Decimal('0.01'))),
            }
        )
    total_pnl = current - invested
    total_pct = (total_pnl / invested * 100) if invested else Decimal('0')
    allocation = []
    if current > 0:
        for item in items:
            share = (Decimal(item['current_value']) / current * 100).quantize(Decimal('0.01'))
            allocation.append(
                {'asset_id': item['asset_id'], 'symbol': item['symbol'], 'percent': str(share)}
            )
    return {
        'environment': 'PAPER TRADING',
        'wallet_balance': str(wallet.balance),
        'invested_amount': str(invested),
        'current_value': str(current),
        'total_portfolio_value': str(current + wallet.balance),
        'profit_loss': str(total_pnl),
        'profit_loss_percent': str(total_pct.quantize(Decimal('0.01'))),
        'usd_inr_rate': str(_cached_usd_inr()),
        'display_currency': 'USD',
        'holdings': items,
        'allocation': allocation,
    }


def _cached_usd_inr() -> Decimal:
    from django.core.cache import cache

    from core.fx import usd_inr_rate

    fx = cache.get('crypto:usd_inr')
    if fx is None:
        fx = usd_inr_rate()
        cache.set('crypto:usd_inr', fx, 3600)
    return Decimal(str(fx))
