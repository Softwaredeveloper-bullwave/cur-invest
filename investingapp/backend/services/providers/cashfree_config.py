"""Load all Cashfree credentials from environment — never hardcode."""

from dataclasses import dataclass

from django.conf import settings


@dataclass(frozen=True)
class CashfreeSettings:
    client_id: str
    client_secret: str
    environment: str
    secure_id_base_url: str
    payments_base_url: str
    payouts_base_url: str
    api_version: str
    payment_api_version: str
    webhook_secret: str
    payout_webhook_secret: str

    @property
    def is_configured(self) -> bool:
        return bool(self.client_id and self.client_secret)

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in ('production', 'prod', 'live')


def _env(name: str, default: str = '') -> str:
    import os

    value = (getattr(settings, name, None) or os.environ.get(name) or default or '').strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1].strip()
    return value


def _is_test_credential(value: str) -> bool:
    text = (value or '').strip().lower()
    return text.startswith('test') or text.startswith('cfsk_ma_test_') or '_test_' in text


def cashfree_settings() -> CashfreeSettings:
    env = _env('CASHFREE_ENVIRONMENT') or _env('CASHFREE_ENV', 'sandbox')
    client_id = _env('CASHFREE_CLIENT_ID') or _env('SECURE_ID_API_KEY')
    client_secret = _env('CASHFREE_CLIENT_SECRET') or _env('SECURE_ID_API_SECRET')
    # TEST keys must hit sandbox even if .env still says production.
    if _is_test_credential(client_id) or _is_test_credential(client_secret):
        env = 'sandbox'
    is_prod = env.lower() in ('production', 'prod', 'live')

    secure_id_default = (
        'https://api.cashfree.com/verification'
        if is_prod
        else 'https://sandbox.cashfree.com/verification'
    )
    payments_default = (
        'https://api.cashfree.com/pg'
        if is_prod
        else 'https://sandbox.cashfree.com/pg'
    )
    payouts_default = (
        'https://payout-api.cashfree.com/payout/v1'
        if is_prod
        else 'https://payout-gamma.cashfree.com/payout/v1'
    )

    return CashfreeSettings(
        client_id=client_id,
        client_secret=client_secret,
        environment=env,
        secure_id_base_url=(
            secure_id_default
            if (not is_prod and 'sandbox' not in _env('SECURE_ID_BASE_URL', secure_id_default).lower())
            else _env('SECURE_ID_BASE_URL', secure_id_default)
        ),
        payments_base_url=_env('CASHFREE_PAYMENTS_BASE_URL', payments_default),
        payouts_base_url=_env('CASHFREE_PAYOUTS_BASE_URL', payouts_default),
        api_version=_env('CASHFREE_API_VERSION', '2024-12-01'),
        payment_api_version=_env('CASHFREE_PAYMENT_API_VERSION', '2023-08-01'),
        webhook_secret=_env('CASHFREE_PAYMENT_WEBHOOK_SECRET') or _env('CASHFREE_WEBHOOK_SECRET'),
        payout_webhook_secret=_env('CASHFREE_PAYOUT_WEBHOOK_SECRET'),
    )
