"""Report which real APIs are configured."""

from django.conf import settings

from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_payments import is_configured as cashfree_payments_configured
from services.providers.cashfree_secure_id import is_configured as cashfree_secure_id_configured
from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import is_configured as eko_kyc_configured

from .razorpay_service import is_configured as razorpay_configured
from .sms_service import resolve_sms_provider, sms_config_status, uses_2factor_live, uses_twilio_verify

from kyc.notifications import email_config_status


def _kyc_provider_name() -> str:
    return (getattr(settings, 'KYC_PROVIDER', 'cashfree') or 'cashfree').strip().lower()


def _kyc_verification_configured() -> bool:
    from kyc.providers import aadhaar_provider, bank_provider, pan_provider, upi_provider

    providers = {pan_provider(), bank_provider(), upi_provider(), aadhaar_provider()}
    if 'eko' in providers and eko_kyc_configured():
        return True
    if 'cashfree' in providers and cashfree_secure_id_configured():
        return True
    return False


def _market_provider():
    explicit = (getattr(settings, 'MARKET_DATA_PROVIDER', 'auto') or 'auto').lower()
    if explicit != 'auto':
        return explicit
    if (getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip():
        return 'kotak_neo'
    if (getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip():
        return 'alphavantage'
    if (getattr(settings, 'FINNHUB_API_KEY', '') or '').strip():
        return 'finnhub'
    return 'yahoo'


def _cashfree_secure_id_probe() -> dict:
    """Lightweight live probe — confirms IP whitelist + credentials (no billing)."""
    cfg = cashfree_settings()
    if not cfg.is_configured:
        return {'reachable': False, 'code': 'not_configured', 'message': 'Cashfree keys missing.'}

    suffix = cfg.client_id[-6:] if len(cfg.client_id) >= 6 else cfg.client_id
    try:
        import httpx

        url = f'{cfg.secure_id_base_url.rstrip("/")}/bank-account/sync'
        headers = {
            'x-client-id': cfg.client_id,
            'x-client-secret': cfg.client_secret,
            'x-api-version': cfg.api_version,
            'Content-Type': 'application/json',
        }
        response = httpx.post(
            url,
            json={'bank_account': '000000000000', 'ifsc': 'HDFC0000001'},
            headers=headers,
            timeout=20,
        )
        data = {}
        try:
            data = response.json()
        except Exception:
            pass
        code = (data.get('code') or '').lower()
        message = (data.get('message') or response.text[:180] or '').strip()

        if code == 'ip_validation_failed' or 'ip not whitelisted' in message.lower():
            return {
                'reachable': False,
                'clientIdSuffix': suffix,
                'environment': cfg.environment,
                'code': 'ip_not_whitelisted',
                'message': message,
            }

        # Any non-IP response means auth + IP whitelist passed (account may still fail validation).
        return {
            'reachable': True,
            'clientIdSuffix': suffix,
            'environment': cfg.environment,
            'code': code or 'ok',
            'message': message or 'Cashfree Secure ID reachable.',
        }
    except Exception as exc:
        return {
            'reachable': False,
            'clientIdSuffix': suffix,
            'environment': cfg.environment,
            'code': 'connection_failed',
            'message': str(exc)[:180],
        }


def integration_status() -> dict:
    kotak = bool((getattr(settings, 'KOTAK_NEO_ACCESS_TOKEN', '') or '').strip())
    av = bool((getattr(settings, 'ALPHA_VANTAGE_API_KEY', '') or '').strip())
    finnhub = bool((getattr(settings, 'FINNHUB_API_KEY', '') or '').strip())
    provider = _market_provider()
    ai_provider = (getattr(settings, 'AI_PROVIDER', 'ollama') or 'ollama').lower()

    ai_ready = ai_provider == 'ollama' or bool(
        {
            'openai': getattr(settings, 'OPENAI_API_KEY', ''),
            'gemini': getattr(settings, 'GEMINI_API_KEY', ''),
            'groq': getattr(settings, 'GROQ_API_KEY', ''),
        }.get(ai_provider, '')
    )

    cf = cashfree_settings()
    eko = eko_settings()
    email_status = email_config_status()
    sms_status = sms_config_status()

    return {
        'market_data': {
            'provider': provider,
            'configured': kotak or av or finnhub,
            'kotak_neo': kotak,
            'alpha_vantage': av,
            'finnhub': finnhub,
            'fallback': 'yahoo_finance',
        },
        'news': {'provider': 'rss_feeds', 'configured': True},
        'payments': {
            'provider': 'cashfree' if cashfree_payments_configured() else 'razorpay',
            'configured': cashfree_payments_configured() or razorpay_configured(),
            'cashfree': cf.is_configured,
            'razorpay': razorpay_configured(),
        },
        'kyc_verification': {
            'provider': f'{_kyc_provider_name()}_kyc',
            'configured': _kyc_verification_configured(),
            'cashfree': cashfree_secure_id_configured(),
            'eko': eko_kyc_configured(),
            'eko_keys_present': eko.is_configured,
            'cashfreeSecureId': _cashfree_secure_id_probe(),
        },
        'payouts': {
            'provider': 'cashfree_payouts',
            'configured': cf.is_configured,
        },
        'sms_otp': {
            'provider': (
                '2factor_autogen'
                if uses_2factor_live()
                else ('twilio_verify' if uses_twilio_verify() else resolve_sms_provider())
            ),
            'configured': uses_2factor_live() or resolve_sms_provider() != 'console',
            'explicit': sms_status.get('explicit_provider'),
            'twilio_verify': uses_twilio_verify(),
            'twofactor': uses_2factor_live(),
        },
        'email_otp': {
            'configured': email_status.get('ready', False),
            'delivery_chain': email_status.get('delivery_chain', []),
            'smtp': email_status.get('smtp', False),
            'brevo': email_status.get('brevo', False),
            'backend_public_url': email_status.get('backend_public_url', ''),
        },
        'bank_validation': {
            'provider': _kyc_provider_name() if _kyc_verification_configured() else 'razorpay_ifsc',
            'configured': _kyc_verification_configured(),
        },
        'ai_assistant': {
            'provider': ai_provider,
            'configured': ai_ready,
        },
        'crypto_market_data': {
            'provider': (getattr(settings, 'CRYPTO_DATA_PROVIDER', 'coingecko') or 'coingecko'),
            'configured': True,  # CoinGecko public API works without a key
            'api_key_configured': bool((getattr(settings, 'CRYPTO_API_KEY', '') or '').strip()),
            'trading_enabled': bool(getattr(settings, 'CRYPTO_TRADING_ENABLED', False)),
            'note': 'Market data + paper trading only unless CRYPTO_TRADING_ENABLED.',
        },
        'broker': {
            'provider': 'paper_trading',
            'configured': False,
            'note': 'Set KITE_API_KEY or DHAN_ACCESS_TOKEN for live broker (future).',
        },
    }
