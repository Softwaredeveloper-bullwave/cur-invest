"""Cashfree Secure ID — PAN, bank, and UPI verification."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

import httpx

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.kyc')

ACCEPTABLE_NAME_MATCHES = frozenset(
    {'DIRECT_MATCH', 'GOOD_PARTIAL_MATCH', 'MODERATE_PARTIAL_MATCH', 'MATCH'}
)
BANK_NAME_REJECT_MATCHES = frozenset({'NO_MATCH', 'POOR_PARTIAL_MATCH'})


class CashfreeSecureIdError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _headers(cfg) -> dict:
    return {
        'x-client-id': cfg.client_id,
        'x-client-secret': cfg.client_secret,
        'x-api-version': cfg.api_version,
        'Content-Type': 'application/json',
    }


def _extract_error_code(data: dict, status_code: int, message: str) -> str:
    code = (data.get('code') or (data.get('error') or {}).get('code') or '').strip()
    if code:
        return code.lower()
    lowered = (message or '').lower()
    if status_code == 429 or 'rate limit' in lowered or 'too many requests' in lowered:
        return 'rate_limit'
    if status_code == 401 or 'authentication' in lowered:
        return 'auth_failed'
    if status_code == 403 or 'ip not whitelisted' in lowered or 'ip_validation' in lowered:
        return 'ip_not_whitelisted'
    if 'timeout' in lowered or status_code == 504:
        return 'timeout'
    if 'failed at bank' in lowered or 'failed_at_bank' in lowered:
        return 'failed_at_bank'
    if 'insufficient balance' in lowered:
        return 'insufficient_balance'
    if 'invalid ifsc' in lowered:
        return 'invalid_ifsc_fail'
    if 'invalid vpa' in lowered or 'invalid upi' in lowered:
        return 'upi_invalid'
    if status_code == 403:
        return 'access_denied'
    return ''


def _post(path: str, payload: dict, *, timeout: float = 45) -> dict:
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreeSecureIdError('Cashfree Secure ID credentials are not configured.', 'not_configured')

    url = f'{cfg.secure_id_base_url.rstrip("/")}{path}'
    try:
        with httpx.Client(timeout=timeout) as client:
            response = client.post(url, json=payload, headers=_headers(cfg))
    except httpx.TimeoutException as exc:
        raise CashfreeSecureIdError(
            'Cashfree is taking too long to respond. Please try again in a moment.',
            'timeout',
        ) from exc
    except httpx.HTTPError as exc:
        raise CashfreeSecureIdError(f'Cashfree connection failed: {exc}', 'connection_failed') from exc

    data = {}
    try:
        data = response.json()
    except Exception:
        pass

    if response.status_code == 401:
        raise CashfreeSecureIdError(
            data.get('message') or 'Invalid Cashfree client ID or secret.',
            'auth_failed',
        )
    if response.status_code == 403:
        raise CashfreeSecureIdError(
            data.get('message') or 'Access denied. Whitelist server IP in Cashfree Secure ID dashboard.',
            _extract_error_code(data, response.status_code, data.get('message', '')) or 'access_denied',
        )
    if response.status_code == 429:
        raise CashfreeSecureIdError(
            data.get('message') or 'Cashfree rate limit reached. Please wait and retry.',
            'rate_limit',
        )
    if response.is_error:
        message = (
            data.get('message')
            or (data.get('error') or {}).get('message')
            or response.text[:240]
            or f'Cashfree error ({response.status_code})'
        )
        code = _extract_error_code(data, response.status_code, message)
        if code == 'failed_at_bank':
            if not cfg.is_production:
                message = (
                    'Cashfree sandbox does not verify real bank accounts — only official test data works. '
                    'Try test account 026291800001191 with IFSC YESB0000262 (success). '
                    'Wrong test account 026291800001190 should fail with a different error.'
                )
            else:
                message = (
                    'Cashfree could not verify this bank account. '
                    'Check the account number and IFSC, then retry.'
                )
        raise CashfreeSecureIdError(message, code)

    return data


def verify_pan(pan: str, name: str = '') -> dict:
    payload = {'pan': pan.upper().strip()}
    if name:
        payload['name'] = name.strip()

    data = _post('/pan', payload)
    if not data.get('valid'):
        message = data.get('message') or 'Invalid PAN or PAN not found.'
        raise CashfreeSecureIdError(message, 'invalid_pan')

    match_result = (data.get('name_match_result') or '').upper()
    if name and match_result in {'NO_MATCH', 'POOR_PARTIAL_MATCH'}:
        registered = data.get('registered_name') or data.get('name_pan_card') or ''
        hint = f' Registered name: {registered}.' if registered else ''
        raise CashfreeSecureIdError(
            (data.get('message') or 'Name on PAN does not match the name you entered.') + hint,
            'name_mismatch',
        )

    return {
        'reference_id': str(data.get('reference_id', '')),
        'registered_name': data.get('registered_name') or data.get('name_pan_card') or '',
        'pan_type': data.get('type', ''),
        'name_match_result': match_result,
        'name_match_score': data.get('name_match_score'),
        'valid': True,
        'dob': data.get('dob') or data.get('date_of_birth') or data.get('birth_date') or '',
    }


def verify_bank_account(*, bank_account: str, ifsc: str, name: str = '', phone: str = '') -> dict:
    payload = {'bank_account': bank_account.strip(), 'ifsc': ifsc.upper().strip()}
    if name:
        payload['name'] = name.strip()
    if phone:
        payload['phone'] = phone.strip()

    data = _post('/bank-account/sync', payload)
    status = (data.get('account_status') or '').upper()
    if status != 'VALID':
        code = (data.get('account_status_code') or 'INVALID').upper()
        raise CashfreeSecureIdError(_bank_error_message(code), code.lower())

    return {
        'reference_id': str(data.get('reference_id', '')),
        'name_at_bank': data.get('name_at_bank') or '',
        'bank_name': data.get('bank_name') or '',
        'branch': data.get('branch') or '',
        'city': data.get('city') or '',
        'name_match_result': (data.get('name_match_result') or '').upper(),
        'name_match_score': data.get('name_match_score'),
        'account_status': status,
        'verification_method': 'penny_drop',
    }


def verify_upi_vpa(
    *,
    customer_vpa: str,
    name: str = '',
    verification_id: str = '',
) -> dict:
    """Validate a UPI VPA via Cashfree Secure ID UPI Penny Drop."""
    vpa = customer_vpa.strip().lower()
    vid = (verification_id or uuid.uuid4().hex[:32])[:50]
    payload = {
        'verification_id': vid,
        'vpa': vpa,
        'user_consent': {
            'obtained': True,
            'type': 'EXPLICIT',
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'purpose': 'KYC UPI verification for investment account onboarding',
        },
    }
    if name:
        payload['name'] = name.strip()

    data = _post('/upi/penny-drop', payload)
    status = (data.get('status') or '').upper()
    if status not in {'VALID', 'SUCCESS'}:
        raise CashfreeSecureIdError(
            data.get('message') or 'UPI ID is invalid or could not be verified.',
            'upi_invalid',
        )

    recipient_name = (data.get('name_at_bank') or '').strip()
    if not recipient_name:
        raise CashfreeSecureIdError(
            'Cashfree did not return a verified payee name for this UPI ID.',
            'upi_name_missing',
        )

    return {
        'vpa': (data.get('vpa') or vpa).strip().lower(),
        'valid': True,
        'recipient_name': recipient_name,
        'mobile_number': '',
        'reference_id': str(data.get('reference_id') or vid),
        'verification_method': 'upi_penny_drop',
        'ifsc': data.get('ifsc') or '',
        'bank_account': data.get('bank_account') or '',
    }


def _bank_error_message(code: str) -> str:
    normalized = (code or '').upper()
    return {
        'INVALID_ACCOUNT_FAIL': 'Bank account number is invalid.',
        'INVALID_IFSC_FAIL': 'IFSC code is invalid.',
        'ACCOUNT_BLOCKED': 'This bank account is blocked.',
        'NRE_ACCOUNT_FAIL': 'NRE accounts are not supported.',
        'FRAUD_ACCOUNT': 'Fraud activity detected for this account.',
        'INSUFFICIENT_BALANCE': 'Insufficient Cashfree wallet balance for bank verification.',
        'CONNECTION_TIMEOUT': 'Bank verification timed out. Please retry.',
        'NPCI_UNAVAILABLE': 'Bank verification is temporarily unavailable. Please retry.',
        'FAILED_AT_BANK': 'Bank verification failed at the bank. Please retry.',
        'SOURCE_BANK_DECLINED': 'Bank declined the verification request.',
        'BENE_BANK_DECLINED': 'Beneficiary bank declined the verification request.',
        'IMPS_MODE_FAIL': 'Could not verify this account via IMPS.',
        'BENEFICIARY_BANK_OFFLINE': 'Beneficiary bank is offline. Please retry later.',
    }.get(normalized, f'Bank verification failed ({normalized or code}).')
