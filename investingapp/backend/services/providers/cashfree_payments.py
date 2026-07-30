"""Cashfree Payment Gateway — order creation and webhook verification."""

import base64
import hashlib
import hmac
import logging
import uuid
from decimal import Decimal

import httpx
from django.conf import settings

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.payments')


class CashfreePaymentError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _pg_headers(cfg) -> dict:
    return {
        'x-client-id': cfg.client_id,
        'x-client-secret': cfg.client_secret,
        'x-api-version': cfg.payment_api_version,
        'Content-Type': 'application/json',
    }


def create_payment_order(
    *,
    amount_inr: Decimal,
    customer_id: str,
    customer_phone: str,
    customer_email: str = '',
    return_url: str = '',
) -> dict:
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreePaymentError('Cashfree Payments credentials are not configured.')

    order_id = f'bw_{uuid.uuid4().hex[:16]}'
    payload = {
        'order_id': order_id,
        'order_amount': float(amount_inr),
        'order_currency': 'INR',
        'customer_details': {
            'customer_id': customer_id,
            'customer_phone': customer_phone,
            'customer_email': customer_email or f'{customer_phone}@bullwave.app',
        },
    }
    public_base = (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').rstrip('/')
    webhook_url = ''
    if public_base.startswith('https://'):
        webhook_url = f'{public_base}/api/v1/payment-webhook/'
    order_meta = {}
    if return_url.startswith('https://'):
        order_meta['return_url'] = return_url
    if webhook_url:
        order_meta['notify_url'] = webhook_url
    if order_meta:
        payload['order_meta'] = order_meta

    url = f'{cfg.payments_base_url.rstrip("/")}/orders'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.post(url, json=payload, headers=_pg_headers(cfg))
    except httpx.HTTPError as exc:
        raise CashfreePaymentError(f'Cashfree Payments connection failed: {exc}') from exc

    data = response.json() if response.content else {}
    if response.is_error:
        raise CashfreePaymentError(
            data.get('message') or data.get('error') or f'Payment order failed ({response.status_code})'
        )

    return {
        'order_id': data.get('order_id') or order_id,
        'payment_session_id': data.get('payment_session_id', ''),
        'order_amount': float(amount_inr),
        'order_currency': 'INR',
        'environment': 'PRODUCTION' if cfg.is_production else 'SANDBOX',
    }


def fetch_order_status(order_id: str) -> dict:
    """Fetch live order status from Cashfree PG."""
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreePaymentError('Cashfree Payments credentials are not configured.')

    url = f'{cfg.payments_base_url.rstrip("/")}/orders/{order_id}'
    try:
        with httpx.Client(timeout=30) as client:
            response = client.get(url, headers=_pg_headers(cfg))
    except httpx.HTTPError as exc:
        raise CashfreePaymentError(f'Cashfree Payments connection failed: {exc}') from exc

    data = response.json() if response.content else {}
    if response.is_error:
        raise CashfreePaymentError(
            data.get('message') or data.get('error') or f'Order lookup failed ({response.status_code})'
        )
    return data


def is_order_paid(order_data: dict) -> bool:
    order_status = (order_data.get('order_status') or '').upper()
    if order_status == 'PAID':
        return True
    payment_status = (order_data.get('payment_status') or '').upper()
    return payment_status in ('SUCCESS', 'PAID')


def extract_payment_id(order_data: dict) -> str:
    payment = order_data.get('payment') or {}
    if isinstance(payment, dict):
        return str(payment.get('cf_payment_id') or payment.get('payment_id') or '')
    return ''


def verify_payment_webhook(raw_body: bytes, signature: str, timestamp: str = '') -> bool:
    cfg = cashfree_settings()
    secret = cfg.webhook_secret
    if not secret:
        logger.warning('CASHFREE_PAYMENT_WEBHOOK_SECRET not set — webhook rejected.')
        return False

    signed_payload = timestamp + raw_body.decode('utf-8') if timestamp else raw_body.decode('utf-8')
    expected = hmac.new(secret.encode(), signed_payload.encode(), hashlib.sha256).digest()

    try:
        received = base64.b64decode(signature)
    except Exception:
        return False
    return hmac.compare_digest(expected, received)
