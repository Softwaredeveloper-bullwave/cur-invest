"""Shared wallet credit logic for Cashfree deposits."""

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification
from finance.models import PaymentOrder, Wallet, WalletTransaction


@transaction.atomic
def credit_payment_order(*, payment_order: PaymentOrder, payment_id: str = '') -> Wallet:
    """Credit wallet for a paid order. Idempotent when order is already paid."""
    payment_order = PaymentOrder.objects.select_for_update().get(pk=payment_order.pk)
    if payment_order.status == PaymentOrder.Status.PAID:
        wallet, _ = Wallet.objects.get_or_create(user=payment_order.user)
        return wallet

    wallet, _ = Wallet.objects.get_or_create(user=payment_order.user)
    wallet = Wallet.objects.select_for_update().get(pk=wallet.pk)

    WalletTransaction.objects.create(
        wallet=wallet,
        type=WalletTransaction.TxType.DEPOSIT,
        amount=payment_order.amount,
        status=WalletTransaction.Status.COMPLETED,
    )
    wallet.balance += payment_order.amount
    wallet.save(update_fields=['balance'])

    payment_order.payment_id = payment_id or payment_order.payment_id
    payment_order.status = PaymentOrder.Status.PAID
    payment_order.paid_at = timezone.now()
    payment_order.save()

    Notification.objects.create(
        user=payment_order.user,
        title='Deposit Successful',
        message=f'₹{payment_order.amount:,.0f} added to your wallet.',
        type='wallet',
    )
    return wallet


def webhook_indicates_paid(payload: dict) -> tuple[bool, str, str]:
    """Return (is_paid, order_id, payment_id) from a Cashfree webhook payload."""
    data = payload.get('data', {}) or {}
    order = data.get('order', {}) or data
    payment = data.get('payment', {}) or {}

    order_id = order.get('order_id') or data.get('order_id') or ''
    order_status = (order.get('order_status') or data.get('order_status') or '').upper()
    payment_status = (payment.get('payment_status') or data.get('payment_status') or '').upper()

    payment_id = str(payment.get('cf_payment_id') or payment.get('payment_id') or data.get('cf_payment_id') or '')
    is_paid = order_status == 'PAID' or payment_status in ('SUCCESS', 'PAID')
    return is_paid, order_id, payment_id
