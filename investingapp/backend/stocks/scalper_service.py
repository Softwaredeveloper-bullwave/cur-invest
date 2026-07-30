"""Fast paper scalper orders with limit entry and OCO risk exits."""

import logging
from datetime import date
from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .market_data_service import refresh_stock
from .models import OptionHolding, ScalperOrder, Stock, StockHolding
from .option_trading_service import place_option_order
from .options_service import get_option_chain
from .trading_service import place_paper_order


class ScalperError(Exception):
    pass


logger = logging.getLogger('bullwave.market')


def _decimal(value, field, *, required=False):
    if value in (None, ''):
        if required:
            raise ScalperError(f'{field} is required.')
        return None
    try:
        result = Decimal(str(value))
    except Exception as exc:
        raise ScalperError(f'Invalid {field}.') from exc
    if result <= 0:
        raise ScalperError(f'{field} must be greater than zero.')
    return result


def _option_price(order: ScalperOrder) -> Decimal:
    chain = get_option_chain(order.underlying, expiry=order.expiry.isoformat(), fast=False)
    if not chain:
        raise ScalperError('Option quote is unavailable.')
    for contract in chain.get('contracts', []):
        if (
            Decimal(str(contract['strike'])) == order.strike
            and str(contract.get('type') or contract.get('option_type')).upper() == order.option_type
            and str(contract['expiry'])[:10] == order.expiry.isoformat()
        ):
            return Decimal(str(contract['ltp']))
    raise ScalperError('Option contract is no longer available in the chain.')


def current_scalper_price(order: ScalperOrder) -> Decimal:
    if order.instrument_type == ScalperOrder.InstrumentType.STOCK:
        stock = refresh_stock(order.stock.symbol)
        return Decimal(str(stock.ltp))
    return _option_price(order)


def serialize_scalper_order(order: ScalperOrder) -> dict:
    symbol = order.stock.symbol if order.stock_id else order.underlying
    return {
        'id': str(order.id),
        'instrumentType': order.instrument_type,
        'symbol': symbol,
        'underlying': order.underlying,
        'assetClass': order.asset_class,
        'strike': float(order.strike) if order.strike is not None else None,
        'optionType': order.option_type,
        'expiry': order.expiry.isoformat() if order.expiry else None,
        'side': order.side,
        'quantity': order.quantity,
        'orderType': order.order_type,
        'requestedPrice': float(order.requested_price) if order.requested_price else None,
        'limitPrice': float(order.limit_price) if order.limit_price else None,
        'fillPrice': float(order.fill_price) if order.fill_price else None,
        'stopLoss': float(order.stop_loss) if order.stop_loss else None,
        'targetPrice': float(order.target_price) if order.target_price else None,
        'trailingStopPercent': (
            float(order.trailing_stop_percent) if order.trailing_stop_percent else None
        ),
        'highWaterMark': float(order.high_water_mark) if order.high_water_mark else None,
        'status': order.status,
        'exitReason': order.exit_reason,
        'errorMessage': order.error_message,
        'entryTradeId': order.entry_trade_id,
        'exitTradeId': order.exit_trade_id,
        'createdAt': order.created_at.isoformat(),
        'filledAt': order.filled_at.isoformat() if order.filled_at else None,
        'closedAt': order.closed_at.isoformat() if order.closed_at else None,
    }


def _execute(order: ScalperOrder, price: Decimal) -> dict:
    if order.instrument_type == ScalperOrder.InstrumentType.STOCK:
        return place_paper_order(
            order.user,
            symbol=order.stock.symbol,
            side=order.side,
            quantity=order.quantity,
        )
    return place_option_order(
        order.user,
        underlying=order.underlying,
        strike=order.strike,
        option_type=order.option_type,
        expiry=order.expiry,
        side=order.side,
        quantity=order.quantity,
        premium=price,
        asset_class=order.asset_class,
    )


def _validate_risk_prices(order: ScalperOrder, reference: Decimal):
    if order.side != 'BUY':
        if order.stop_loss or order.target_price or order.trailing_stop_percent:
            raise ScalperError('Risk controls can only be attached to a Buy entry.')
        return
    if order.stop_loss and order.stop_loss >= reference:
        raise ScalperError('Stop-loss must be below the entry price.')
    if order.target_price and order.target_price <= reference:
        raise ScalperError('Target must be above the entry price.')
    if order.trailing_stop_percent and order.trailing_stop_percent > Decimal('50'):
        raise ScalperError('Trailing stop must be 50% or less.')


@transaction.atomic
def create_scalper_order(
    user,
    *,
    instrument_type,
    order_type,
    side,
    quantity,
    symbol='',
    underlying='',
    asset_class='equity_fno',
    strike=None,
    option_type='',
    expiry=None,
    requested_price=None,
    limit_price=None,
    stop_loss=None,
    target_price=None,
    trailing_stop_percent=None,
) -> ScalperOrder:
    instrument_type = str(instrument_type).lower()
    order_type = str(order_type).lower()
    side = str(side).upper()
    if instrument_type not in ScalperOrder.InstrumentType.values:
        raise ScalperError('Invalid scalper instrument type.')
    if order_type not in ScalperOrder.OrderType.values:
        raise ScalperError('Order type must be market or limit.')
    if side not in ('BUY', 'SELL'):
        raise ScalperError('Side must be BUY or SELL.')
    if int(quantity) < 1:
        raise ScalperError('Quantity must be at least 1.')

    stock = None
    parsed_expiry = None
    parsed_strike = None
    if instrument_type == ScalperOrder.InstrumentType.STOCK:
        symbol = str(symbol).upper().strip()
        stock = Stock.objects.filter(symbol=symbol).first()
        if not stock:
            stock = refresh_stock(symbol)
    else:
        underlying = str(underlying).upper().strip()
        option_type = str(option_type).upper().strip()
        if option_type not in ('CE', 'PE'):
            raise ScalperError('Option type must be CE or PE.')
        parsed_strike = _decimal(strike, 'strike', required=True)
        try:
            parsed_expiry = expiry if isinstance(expiry, date) else date.fromisoformat(str(expiry)[:10])
        except ValueError as exc:
            raise ScalperError('Invalid option expiry.') from exc

    order = ScalperOrder(
        user=user,
        instrument_type=instrument_type,
        order_type=order_type,
        side=side,
        quantity=int(quantity),
        stock=stock,
        underlying=underlying,
        asset_class=str(asset_class or 'equity_fno').lower(),
        strike=parsed_strike,
        option_type=option_type,
        expiry=parsed_expiry,
        requested_price=_decimal(requested_price, 'requested price'),
        limit_price=_decimal(limit_price, 'limit price', required=order_type == 'limit'),
        stop_loss=_decimal(stop_loss, 'stop-loss'),
        target_price=_decimal(target_price, 'target'),
        trailing_stop_percent=_decimal(trailing_stop_percent, 'trailing stop'),
    )
    reference = order.limit_price or order.requested_price
    if reference is None:
        order.save()
        reference = current_scalper_price(order)
    _validate_risk_prices(order, reference)
    order.save()

    if order.order_type == ScalperOrder.OrderType.MARKET:
        execute_scalper_entry(order.id)
        order.refresh_from_db()
    return order


@transaction.atomic
def execute_scalper_entry(order_id, *, price=None) -> ScalperOrder:
    order = ScalperOrder.objects.select_for_update().select_related('user').get(pk=order_id)
    if order.status != ScalperOrder.Status.PENDING:
        return order
    current = Decimal(str(price)) if price is not None else current_scalper_price(order)
    try:
        trade = _execute(order, current)
    except Exception as exc:
        order.status = ScalperOrder.Status.FAILED
        order.error_message = str(exc)[:280]
        order.last_checked_at = timezone.now()
        order.save(update_fields=['status', 'error_message', 'last_checked_at', 'updated_at'])
        return order
    order.fill_price = Decimal(str(trade.get('price') or trade.get('premium') or current))
    order.high_water_mark = order.fill_price
    order.entry_trade_id = str(trade.get('id') or '')
    order.filled_at = timezone.now()
    order.last_checked_at = timezone.now()
    has_open_position = order.side == 'BUY'
    order.status = ScalperOrder.Status.ACTIVE if has_open_position else ScalperOrder.Status.EXECUTED
    order.save()
    return order


@transaction.atomic
def exit_scalper_order(order_id, *, reason=ScalperOrder.ExitReason.MANUAL, price=None):
    order = ScalperOrder.objects.select_for_update().select_related('user').get(pk=order_id)
    if order.status != ScalperOrder.Status.ACTIVE:
        raise ScalperError('This scalper position is not active.')
    current = Decimal(str(price)) if price is not None else current_scalper_price(order)
    original_side = order.side
    order.side = 'SELL'
    try:
        trade = _execute(order, current)
    finally:
        order.side = original_side
    order.exit_trade_id = str(trade.get('id') or '')
    order.exit_reason = reason
    order.status = ScalperOrder.Status.EXECUTED
    order.closed_at = timezone.now()
    order.last_checked_at = timezone.now()
    order.save()
    Notification.objects.create(
        user=order.user,
        title='Scalper position exited',
        message=f'{serialize_scalper_order(order)["symbol"]} exited by {reason.replace("_", " ")}.',
        type='trade',
    )
    return order


def process_scalper_orders() -> int:
    processed = 0
    ids = list(
        ScalperOrder.objects.filter(
            status__in=[ScalperOrder.Status.PENDING, ScalperOrder.Status.ACTIVE]
        ).values_list('id', flat=True)
    )
    for order_id in ids:
        try:
            with transaction.atomic():
                order = (
                    ScalperOrder.objects.select_for_update()
                    .select_related('user')
                    .get(pk=order_id)
                )
                price = current_scalper_price(order)
                order.last_checked_at = timezone.now()
                if order.status == ScalperOrder.Status.PENDING:
                    hit = (
                        order.side == 'BUY' and price <= order.limit_price
                    ) or (
                        order.side == 'SELL' and price >= order.limit_price
                    )
                    order.save(update_fields=['last_checked_at', 'updated_at'])
                    if hit:
                        execute_scalper_entry(order.id, price=price)
                        processed += 1
                    continue

                high = max(order.high_water_mark or price, price)
                order.high_water_mark = high
                reason = None
                if order.stop_loss and price <= order.stop_loss:
                    reason = ScalperOrder.ExitReason.STOP_LOSS
                elif order.target_price and price >= order.target_price:
                    reason = ScalperOrder.ExitReason.TARGET
                elif order.trailing_stop_percent:
                    trailing_price = high * (
                        Decimal('1') - order.trailing_stop_percent / Decimal('100')
                    )
                    if price <= trailing_price:
                        reason = ScalperOrder.ExitReason.TRAILING
                order.save(update_fields=['high_water_mark', 'last_checked_at', 'updated_at'])
                if reason:
                    exit_scalper_order(order.id, reason=reason, price=price)
                    processed += 1
        except Exception:
            logger.exception('Scalper order processing failed order_id=%s', order_id)
            continue
    return processed


def cancel_scalper_order(user, order_id):
    updated = ScalperOrder.objects.filter(
        pk=order_id,
        user=user,
        status=ScalperOrder.Status.PENDING,
    ).update(status=ScalperOrder.Status.CANCELLED)
    if not updated:
        raise ScalperError('Pending scalper order not found.')


def update_scalper_risk(user, order_id, *, stop_loss=None, target_price=None, trailing_stop_percent=None):
    order = ScalperOrder.objects.get(pk=order_id, user=user, status=ScalperOrder.Status.ACTIVE)
    order.stop_loss = _decimal(stop_loss, 'stop-loss')
    order.target_price = _decimal(target_price, 'target')
    order.trailing_stop_percent = _decimal(trailing_stop_percent, 'trailing stop')
    _validate_risk_prices(order, order.fill_price)
    order.save(update_fields=['stop_loss', 'target_price', 'trailing_stop_percent', 'updated_at'])
    return order
