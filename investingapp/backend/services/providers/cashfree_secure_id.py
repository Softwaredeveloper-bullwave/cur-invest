"""Cashfree Secure ID — PAN, bank, UPI, and DigiLocker Aadhaar verification."""

from __future__ import annotations

import logging
import re
import uuid
from datetime import datetime, timezone

import httpx

from .cashfree_config import cashfree_settings

logger = logging.getLogger('bullwave.kyc')

ACCEPTABLE_NAME_MATCHES = frozenset(
    {'DIRECT_MATCH', 'GOOD_PARTIAL_MATCH', 'MODERATE_PARTIAL_MATCH', 'MATCH'}
)
BANK_NAME_REJECT_MATCHES = frozenset({'NO_MATCH', 'POOR_PARTIAL_MATCH'})


DIGILOCKER_API_VERSION = '2023-12-18'


class CashfreeSecureIdError(Exception):
    def __init__(self, message, code=''):
        super().__init__(message)
        self.code = code


def is_configured() -> bool:
    return cashfree_settings().is_configured


def _headers(cfg, *, api_version: str | None = None, omit_api_version: bool = False) -> dict:
    headers = {
        'x-client-id': cfg.client_id,
        'x-client-secret': cfg.client_secret,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
    }
    if not omit_api_version:
        headers['x-api-version'] = api_version or cfg.api_version
    return headers


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


def _post(
    path: str,
    payload: dict,
    *,
    timeout: float = 45,
    api_version: str | None = None,
    omit_api_version: bool = False,
) -> dict:
    return _handle_response(
        _send(
            'POST',
            path,
            json=payload,
            timeout=timeout,
            api_version=api_version,
            omit_api_version=omit_api_version,
        )
    )


def _get(
    path: str,
    params: dict | None = None,
    *,
    timeout: float = 45,
    api_version: str | None = None,
    omit_api_version: bool = False,
) -> dict:
    return _handle_response(
        _send(
            'GET',
            path,
            params=params,
            timeout=timeout,
            api_version=api_version,
            omit_api_version=omit_api_version,
        )
    )


def _send(
    method: str,
    path: str,
    *,
    timeout: float = 45,
    api_version: str | None = None,
    omit_api_version: bool = False,
    **kwargs,
):
    cfg = cashfree_settings()
    if not cfg.is_configured:
        raise CashfreeSecureIdError('Cashfree Secure ID credentials are not configured.', 'not_configured')

    url = f'{cfg.secure_id_base_url.rstrip("/")}{path}'
    headers = _headers(cfg, api_version=api_version, omit_api_version=omit_api_version)
    try:
        with httpx.Client(timeout=timeout) as client:
            if method == 'GET':
                return client.get(url, params=kwargs.get('params'), headers=headers)
            return client.post(url, json=kwargs.get('json'), headers=headers)
    except httpx.TimeoutException as exc:
        raise CashfreeSecureIdError(
            'Cashfree is taking too long to respond. Please try again in a moment.',
            'timeout',
        ) from exc
    except httpx.HTTPError as exc:
        raise CashfreeSecureIdError(f'Cashfree connection failed: {exc}', 'connection_failed') from exc


def _handle_response(response) -> dict:
    cfg = cashfree_settings()
    data = {}
    try:
        parsed = response.json()
        if isinstance(parsed, dict):
            data = parsed
    except Exception:
        pass

    if response.status_code == 202:
        return {**data, 'status': data.get('status') or 'PENDING'}

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


def create_digilocker_url(*, verification_id: str, redirect_url: str, user_flow: str = 'signup') -> dict:
    """Create Cashfree DigiLocker consent URL (Aadhaar)."""
    vid = re.sub(r'[^A-Za-z0-9._-]', '', verification_id or '')[:50]
    if not vid:
        raise CashfreeSecureIdError('DigiLocker verification id is missing.', 'invalid_request')
    if redirect_url and not redirect_url.lower().startswith('https://'):
        raise CashfreeSecureIdError(
            'Cashfree DigiLocker requires an HTTPS redirect URL (https://api.capitalbullwave.com).',
            'public_redirect_required',
        )
    payload = {
        'verification_id': vid,
        'document_requested': ['AADHAAR'],
        'redirect_url': redirect_url,
        'user_flow': user_flow if user_flow in {'signin', 'signup'} else 'signup',
    }
    cfg = cashfree_settings()
    header_attempts = [
        {'api_version': DIGILOCKER_API_VERSION, 'omit_api_version': False},
        {'api_version': None, 'omit_api_version': True},
        {'api_version': cfg.api_version, 'omit_api_version': False},
    ]
    data = None
    last_error = None
    seen = set()
    for attempt in header_attempts:
        key = (attempt['api_version'], attempt['omit_api_version'])
        if key in seen:
            continue
        seen.add(key)
        try:
            data = _post('/digilocker', payload, **attempt)
            break
        except CashfreeSecureIdError as exc:
            last_error = exc
            logger.warning(
                'Cashfree DigiLocker create failed (version=%s omit=%s code=%s): %s',
                attempt['api_version'] or '-',
                attempt['omit_api_version'],
                getattr(exc, 'code', ''),
                exc,
            )
            if _is_generic_cashfree_failure(exc):
                continue
            raise CashfreeSecureIdError(_digilocker_create_error_message(exc), _digilocker_create_error_code(exc)) from exc
    if data is None:
        raise CashfreeSecureIdError(
            _digilocker_create_error_message(last_error),
            _digilocker_create_error_code(last_error),
        )
    url = (data.get('url') or '').strip()
    reference_id = data.get('reference_id')
    if not url or reference_id in (None, ''):
        raise CashfreeSecureIdError(
            data.get('message') or 'Cashfree did not return a DigiLocker URL.',
            'digilocker_session_failed',
        )
    return {
        'url': url,
        'reference_id': str(reference_id),
        'verification_id': str(data.get('verification_id') or vid),
        'status': str(data.get('status') or 'PENDING'),
    }


def _is_generic_cashfree_failure(exc: CashfreeSecureIdError | None) -> bool:
    if exc is None:
        return False
    lowered = f'{getattr(exc, "code", "")} {exc}'.lower()
    return any(
        token in lowered
        for token in (
            'something went wrong',
            'try after some time',
            'verification_failed',
            'internal_error',
            'temporarily unavailable',
        )
    )


def _digilocker_create_error_code(exc: CashfreeSecureIdError | None) -> str:
    code = (getattr(exc, 'code', '') or '').lower()
    if code in {'ip_not_whitelisted', 'access_denied', 'auth_failed', 'not_configured', 'insufficient_balance', 'rate_limit'}:
        return code
    if '404' in str(exc) or 'not found' in str(exc).lower():
        return 'digilocker_not_enabled'
    if _is_generic_cashfree_failure(exc):
        return 'digilocker_unavailable'
    return code or 'digilocker_session_failed'


def _digilocker_create_error_message(exc: CashfreeSecureIdError | None) -> str:
    original = str(exc or '').strip()
    code = _digilocker_create_error_code(exc)
    if code == 'ip_not_whitelisted' or code == 'access_denied':
        return original or 'Whitelist this server IP in the Cashfree Secure ID dashboard, then retry.'
    if code == 'auth_failed':
        return original or 'Invalid Cashfree client ID or secret.'
    if code == 'insufficient_balance':
        return 'Cashfree wallet balance is too low to start DigiLocker. Add sandbox credits and retry.'
    if code == 'digilocker_not_enabled':
        return (
            'Cashfree DigiLocker is not enabled on this Secure ID account. '
            'Open Verification Suite → DigiLocker and request activation. '
            'Use Secure ID keys, not Payment Gateway keys.'
        )
    if code == 'digilocker_unavailable' or _is_generic_cashfree_failure(exc):
        cfg = cashfree_settings()
        host = cfg.secure_id_base_url
        return (
            'Cashfree could not create a DigiLocker session. '
            f'Using {host}. TEST keys must use sandbox; whitelist 43.204.159.255 in Secure ID; '
            'and ask Cashfree to enable DigiLocker on this merchant if it is still off.'
        )
    return original or 'Cashfree did not return a DigiLocker URL.'


def get_digilocker_identity(*, verification_id: str = '', reference_id: str = '') -> dict:
    """Poll Cashfree DigiLocker and fetch Aadhaar after AUTHENTICATED."""
    params = {}
    if verification_id:
        params['verification_id'] = verification_id
    if reference_id:
        params['reference_id'] = reference_id
    if not params:
        raise CashfreeSecureIdError('Start DigiLocker verification first.', 'invalid_request')

    status_data = _get('/digilocker', params, api_version=DIGILOCKER_API_VERSION)
    status_value = str(status_data.get('status') or '').upper()
    vid = str(status_data.get('verification_id') or verification_id or '')
    ref = str(status_data.get('reference_id') or reference_id or '')

    if status_value in {'EXPIRED', 'CONSENT_DENIED', 'FAILED', 'CANCELLED', 'REJECTED'}:
        return {
            'verification_status': status_value,
            'verification_id': vid,
            'user_details': {},
            'document_consent': [],
        }
    if status_value not in {'AUTHENTICATED', 'SUCCESS', 'VERIFIED', 'COMPLETED'}:
        return {
            'verification_status': 'PENDING',
            'verification_id': vid,
            'user_details': {},
            'document_consent': [],
        }

    doc_params = {}
    if vid:
        doc_params['verification_id'] = vid
    if ref:
        doc_params['reference_id'] = ref
    try:
        document = _get('/digilocker/document/AADHAAR', doc_params, api_version=DIGILOCKER_API_VERSION)
    except CashfreeSecureIdError as exc:
        lowered = str(exc).lower()
        if exc.code == 'pending' or 'not ready' in lowered or 'not available' in lowered:
            return {
                'verification_status': 'PENDING',
                'verification_id': vid,
                'user_details': {},
                'document_consent': [],
            }
        raise

    name = (document.get('name') or '').strip()
    dob = document.get('dob') or document.get('date_of_birth') or ''
    aadhaar_number = str(document.get('aadhaar_number') or document.get('uid') or '')
    return {
        'verification_status': 'SUCCESS' if name else 'PENDING',
        'verification_id': vid,
        'user_details': {
            'name': name,
            'eaadhaar': 'Y' if name else 'N',
            'dob': dob,
            'aadhaar_number': aadhaar_number,
        },
        'document_consent': [{'document_type': 'AADHAAR', 'consent': 'Y'}] if name else [],
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
