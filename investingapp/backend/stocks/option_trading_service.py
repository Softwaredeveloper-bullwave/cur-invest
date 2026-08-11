"""Option contract buy/sell — wallet settlement for equity F&O and commodity options."""

from __future__ import annotations

from datetime import date
from decimal import Decimal, ROUND_HALF_UP

from django.db import transaction

from finance.practice_wallet_service import (
    PracticeWalletError,
    credit_practice_wallet,
    debit_practice_wallet,
)

from .commodity_service import COMMODITY_CATALOG
from .commodity_trading_service import get_usd_inr_rate
from .models import OptionHolding, OptionTrade

LOT_SIZES = {
    'NIFTY': 25,
    'BANKNIFTY': 15,
    'FINNIFTY': 25,
    'SENSEX': 10,
    'MIDCPNIFTY': 50,
    'BANKEX': 15,
}

# Index futures paper margin (~SPAN-style) so 1L practice wallet can trade.
FUTURES_MARGIN_PCT = Decimal('0.12')


class OptionTradingError(Exception):
    pass


def _round2(value) -> float:
    return round(float(value), 2)


def _lot_size(underlying: str, asset_class: str) -> int:
    if asset_class == OptionHolding.AssetClass.COMMODITY:
        return 1
    return LOT_SIZES.get(underlying.upper(), 1)


def _inr_from_usd(usd_amount: Decimal, rate: Decimal) -> Decimal:
    return (usd_amount * rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _order_amount_inr(
    *,
    premium: Decimal,
    quantity: int,
    lot_size: int,
    asset_class: str,
    rate: Decimal,
    option_type: str = 'CE',
) -> Decimal:
    total = premium * quantity * lot_size
    if option_type.upper() == 'FU':
        total = total * FUTURES_MARGIN_PCT
    if asset_class == OptionHolding.AssetClass.COMMODITY:
        return _inr_from_usd(total, rate)
    return total.quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)


def _contract_label(underlying: str, strike, option_type: str, expiry: date) -> str:
    if option_type.upper() == 'FU':
        return f'{underlying.upper()} FUT {expiry.isoformat()}'
    return f'{underlying.upper()} {float(strike):g} {option_type} {expiry.isoformat()}'


def _holding_key(user, *, underlying, strike, option_type, expiry, asset_class):
    return OptionHolding.objects.filter(
        user=user,
        underlying=underlying.upper(),
        strike=strike,
        option_type=option_type.upper(),
        expiry=expiry,
        asset_class=asset_class,
    ).first()


def build_option_trade_payload(
    trade: OptionTrade,
    holding: OptionHolding | None = None,
) -> dict:
    label = _contract_label(trade.underlying, trade.strike, trade.option_type, trade.expiry)
    payload = {
        'id': str(trade.id),
        'underlying': trade.underlying,
        'assetClass': trade.asset_class,
        'strike': _round2(trade.strike),
        'optionType': trade.option_type,
        'expiry': trade.expiry.isoformat(),
        'contractLabel': label,
        'side': trade.side,
        'quantity': trade.quantity,
        'premium': _round2(trade.premium),
        'lotSize': trade.lot_size,
        'amountInr': _round2(trade.amount_inr),
        'time': trade.created_at.isoformat(),
        'status': trade.status,
        'orderValueInr': _round2(trade.amount_inr),
    }
    if trade.avg_premium is not None:
        payload['avgPremium'] = _round2(trade.avg_premium)
    if trade.realized_pnl_inr is not None:
        payload['realizedPnlInr'] = _round2(trade.realized_pnl_inr)
    if holding and holding.quantity > 0:
        payload['holdingQty'] = holding.quantity
        payload['holdingAvgPremium'] = _round2(holding.avg_premium)
    return payload


def _holding_payload(holding: OptionHolding) -> dict:
    label = _contract_label(holding.underlying, holding.strike, holding.option_type, holding.expiry)
    return {
        'underlying': holding.underlying,
        'assetClass': holding.asset_class,
        'strike': _round2(holding.strike),
        'optionType': holding.option_type,
        'expiry': holding.expiry.isoformat(),
        'contractLabel': label,
        'quantity': holding.quantity,
        'avgPremium': _round2(holding.avg_premium),
        'lotSize': holding.lot_size,
    }


def list_option_holdings(user, *, asset_class: str | None = None) -> list[dict]:
    qs = OptionHolding.objects.filter(user=user)
    if asset_class:
        qs = qs.filter(asset_class=asset_class)
    return [_holding_payload(h) for h in qs]


def list_recent_option_trades(user, limit: int = 30) -> list[dict]:
    trades = OptionTrade.objects.filter(user=user).order_by('-created_at')[:limit]
    rows = []
    for trade in trades:
        holding = _holding_key(
            user,
            underlying=trade.underlying,
            strike=trade.strike,
            option_type=trade.option_type,
            expiry=trade.expiry,
            asset_class=trade.asset_class,
        )
        rows.append(build_option_trade_payload(trade, holding))
    return rows


@transaction.atomic
def place_option_order(
    user,
    *,
    underlying: str,
    strike,
    option_type: str,
    expiry,
    side: str,
    quantity: int,
    premium,
    asset_class: str = OptionHolding.AssetClass.EQUITY_FNO,
) -> dict:
    underlying = underlying.upper().strip()
    option_type = option_type.upper().strip()
    side = side.upper().strip()
    asset_class = (asset_class or OptionHolding.AssetClass.EQUITY_FNO).strip().lower()

    if side not in ('BUY', 'SELL'):
        raise OptionTradingError('Invalid order side.')
    if option_type not in ('CE', 'PE', 'FU'):
        raise OptionTradingError('Invalid option type. Use CE, PE, or FU (index futures).')
    if quantity < 1:
        raise OptionTradingError('Quantity must be at least 1 lot.')

    if asset_class == OptionHolding.AssetClass.COMMODITY:
        if underlying not in COMMODITY_CATALOG:
            raise OptionTradingError('Commodity not found.')
        if option_type == 'FU':
            raise OptionTradingError('Index futures are only available for equity F&O.')
    elif asset_class != OptionHolding.AssetClass.EQUITY_FNO:
        raise OptionTradingError('Invalid asset class.')

    if isinstance(expiry, str):
        expiry = date.fromisoformat(expiry[:10])

    premium = Decimal(str(premium))
    if premium <= 0:
        raise OptionTradingError('Invalid price.')

    strike = Decimal(str(strike))
    if option_type == 'FU':
        # One futures book per underlying+expiry (spot stored as avg_premium).
        strike = Decimal('0')
    lot_size = _lot_size(underlying, asset_class)
    rate = get_usd_inr_rate() if asset_class == OptionHolding.AssetClass.COMMODITY else Decimal('1')
    order_inr = _order_amount_inr(
        premium=premium,
        quantity=quantity,
        lot_size=lot_size,
        asset_class=asset_class,
        rate=rate,
        option_type=option_type,
    )

    holding = _holding_key(
        user,
        underlying=underlying,
        strike=strike,
        option_type=option_type,
        expiry=expiry,
        asset_class=asset_class,
    )
    if side == 'SELL':
        if not holding or holding.quantity < quantity:
            available = holding.quantity if holding else 0
            raise OptionTradingError(f'Insufficient lots. You hold {available}.')
        avg_cost = holding.avg_premium
        if option_type == 'FU':
            # Return locked margin + full mark-to-market PnL.
            locked_margin = _order_amount_inr(
                premium=avg_cost,
                quantity=quantity,
                lot_size=lot_size,
                asset_class=asset_class,
                rate=rate,
                option_type=option_type,
            )
            realized_pnl_inr = ((premium - avg_cost) * quantity * lot_size).quantize(
                Decimal('0.01'), rounding=ROUND_HALF_UP
            )
            credit_inr = locked_margin + realized_pnl_inr
            order_inr = credit_inr
        else:
            buy_inr = _order_amount_inr(
                premium=avg_cost,
                quantity=quantity,
                lot_size=lot_size,
                asset_class=asset_class,
                rate=rate,
                option_type=option_type,
            )
            realized_pnl_inr = order_inr - buy_inr
            credit_inr = order_inr
        trade = OptionTrade.objects.create(
            user=user,
            underlying=underlying,
            asset_class=asset_class,
            strike=strike,
            option_type=option_type,
            expiry=expiry,
            side=side,
            quantity=quantity,
            premium=premium,
            lot_size=lot_size,
            amount_inr=order_inr,
            avg_premium=avg_cost,
            realized_pnl_inr=realized_pnl_inr,
        )
        holding.quantity -= quantity
        if holding.quantity == 0:
            holding.delete()
            holding = None
        else:
            holding.save(update_fields=['quantity'])
        practice_wallet = credit_practice_wallet(
            user,
            credit_inr,
            reference=f'OPT-{trade.id}',
            description=(
                f'Paper futures sell {underlying} × {quantity}'
                if option_type == 'FU'
                else f'Paper option sell {underlying} {option_type} × {quantity}'
            ),
        )
    else:
        trade = OptionTrade.objects.create(
            user=user,
            underlying=underlying,
            asset_class=asset_class,
            strike=strike,
            option_type=option_type,
            expiry=expiry,
            side=side,
            quantity=quantity,
            premium=premium,
            lot_size=lot_size,
            amount_inr=order_inr,
        )
        if holding:
            total_cost = holding.quantity * holding.avg_premium + Decimal(quantity) * premium
            holding.quantity += quantity
            holding.avg_premium = total_cost / holding.quantity
            holding.save()
        else:
            holding = OptionHolding.objects.create(
                user=user,
                underlying=underlying,
                asset_class=asset_class,
                strike=strike,
                option_type=option_type,
                expiry=expiry,
                quantity=quantity,
                avg_premium=premium,
                lot_size=lot_size,
            )
        try:
            practice_wallet = debit_practice_wallet(
                user,
                order_inr,
                reference=f'OPT-{trade.id}',
                description=(
                    f'Paper futures buy {underlying} × {quantity}'
                    if option_type == 'FU'
                    else f'Paper option buy {underlying} {option_type} × {quantity}'
                ),
            )
        except PracticeWalletError as exc:
            raise OptionTradingError(str(exc)) from exc

    payload = build_option_trade_payload(trade, holding)
    payload['practiceWalletBalance'] = _round2(practice_wallet.balance)
    return payload
