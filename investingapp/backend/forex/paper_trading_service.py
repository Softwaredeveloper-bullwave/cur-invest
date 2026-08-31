"""Forex paper trading — VIRTUAL FUNDS ONLY. No live FX execution."""

from __future__ import annotations

from decimal import Decimal, ROUND_DOWN

from django.db import transaction
from django.utils import timezone

from core.fx import usd_inr_rate

from .models import ForexHolding, ForexPair, ForexPracticeWallet, ForexTransaction
from .pairs import normalize_pair_id
from .services import ForexService

STARTING_BALANCE = Decimal('100000.00')
REFILL_THRESHOLD = Decimal('10000.00')


class ForexPaperTradingError(Exception):
    pass


def get_or_create_wallet(user) -> ForexPracticeWallet:
    wallet, _ = ForexPracticeWallet.objects.get_or_create(
        user=user,
        defaults={'balance': STARTING_BALANCE},
    )
    if wallet.balance < REFILL_THRESHOLD:
        wallet.balance = STARTING_BALANCE
        wallet.last_refilled_at = timezone.now()
        wallet.save(update_fields=['balance', 'last_refilled_at', 'updated_at'])
    return wallet


def _inr_notional(pair: ForexPair, price: Decimal, qty: Decimal) -> Decimal:
    quote = (pair.quote_currency or 'USD').upper()
    if quote == 'INR':
        fx = Decimal('1')
    else:
        fx = usd_inr_rate()
    return (price * qty * fx).quantize(Decimal('0.01'), rounding=ROUND_DOWN)


@transaction.atomic
def place_paper_order(user, *, pair_id: str, side: str, quantity: Decimal) -> dict:
    side = (side or '').upper().strip()
    if side not in ('BUY', 'SELL'):
        raise ForexPaperTradingError('Side must be BUY or SELL.')
    qty = Decimal(str(quantity))
    if qty <= 0:
        raise ForexPaperTradingError('Quantity must be positive.')

    pid = normalize_pair_id(pair_id)
    pair = ForexPair.objects.filter(pk=pid).first()
    data = ForexService().get_pair(pid)
    if not pair:
        pair, _ = ForexPair.objects.get_or_create(
            id=pid,
            defaults={
                'base_currency': (data.get('base_currency') or '')[:8],
                'quote_currency': (data.get('quote_currency') or '')[:8],
                'symbol': (data.get('symbol') or pid)[:16],
                'name': (data.get('name') or pid)[:120],
                'category': (data.get('category') or 'Majors')[:32],
            },
        )
    price = Decimal(str(data.get('current_price') or 0))
    if price <= 0:
        raise ForexPaperTradingError('Unable to fetch a valid market price.')
    total = _inr_notional(pair, price, qty)
    wallet = ForexPracticeWallet.objects.select_for_update().get(pk=get_or_create_wallet(user).pk)

    if side == 'BUY':
        if wallet.balance < total:
            raise ForexPaperTradingError('Insufficient paper trading balance.')
        wallet.balance -= total
        wallet.save(update_fields=['balance', 'updated_at'])
        holding, _ = ForexHolding.objects.select_for_update().get_or_create(
            user=user, pair=pair, defaults={'quantity': Decimal('0'), 'avg_price': Decimal('0')}
        )
        new_qty = holding.quantity + qty
        if new_qty > 0:
            holding.avg_price = ((holding.avg_price * holding.quantity) + (price * qty)) / new_qty
        holding.quantity = new_qty
        holding.save()
    else:
        holding = ForexHolding.objects.select_for_update().filter(user=user, pair=pair).first()
        if not holding or holding.quantity < qty:
            raise ForexPaperTradingError('Insufficient holding quantity.')
        holding.quantity -= qty
        if holding.quantity == 0:
            holding.avg_price = Decimal('0')
        holding.save()
        wallet.balance += total
        wallet.save(update_fields=['balance', 'updated_at'])

    tx = ForexTransaction.objects.create(
        user=user,
        pair=pair,
        tx_type=ForexTransaction.TxType.BUY if side == 'BUY' else ForexTransaction.TxType.SELL,
        quantity=qty,
        price=price,
        total_value=total,
        currency='INR',
        exchange='PAPER',
        status=ForexTransaction.Status.COMPLETED,
        is_paper=True,
        notes='PAPER TRADING',
    )
    return {
        'id': str(tx.id),
        'pair_id': pair.id,
        'symbol': pair.symbol,
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
    holdings = list(ForexHolding.objects.filter(user=user, quantity__gt=0).select_related('pair'))
    invested = Decimal('0')
    current = Decimal('0')
    rows = []
    svc = ForexService()
    for h in holdings:
        try:
            quote = svc.get_price(h.pair_id)
            px = Decimal(str(quote.get('current_price') or 0))
        except Exception:
            px = h.avg_price
        value = _inr_notional(h.pair, px, h.quantity)
        cost = _inr_notional(h.pair, h.avg_price, h.quantity)
        invested += cost
        current += value
        rows.append(
            {
                'pair_id': h.pair_id,
                'symbol': h.pair.symbol,
                'name': h.pair.name,
                'quantity': str(h.quantity),
                'avg_price': str(h.avg_price),
                'current_price': str(px),
                'current_value': str(value),
                'profit_loss': str(value - cost),
            }
        )
    pnl = current - invested
    pct = (pnl / invested * 100) if invested else Decimal('0')
    return {
        'environment': 'PAPER TRADING',
        'wallet_balance': str(wallet.balance),
        'invested_amount': str(invested),
        'current_value': str(current),
        'total_portfolio_value': str(wallet.balance + current),
        'profit_loss': str(pnl),
        'profit_loss_percent': str(pct.quantize(Decimal('0.01'))),
        'usd_inr_rate': str(usd_inr_rate()),
        'display_currency': 'USD',
        'holdings': rows,
        'allocation': [],
    }
