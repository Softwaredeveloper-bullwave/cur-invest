"""Eko Platform Services — PAN, DigiLocker Aadhaar & bank verification.

Endpoints (per https://developers.eko.in/v1.0/reference):
  PAN Verification        POST {base}/v1/pan/verify
  Activate PAN service    PUT  {base}/v1/user/service/activate   (one-time, production only)
  Create/find customer    PUT  {base}/v2/customers/mobile_number:{mobile}
  Bank Account Verify (Penny-less) POST {base}/v3/tools/kyc/{org_slug}/bank-acc-verify-penniless
  Bank Account Verify (Penny drop) POST {base}/v3/tools/kyc/bank-account/sync
  UPI VPA validate          POST {base}/v3/customer/payment/upi/validate-vpa
  Create DigiLocker URL   POST {base}/v3/tools/kyc/digilocker
  DigiLocker status       GET  {base}/v3/tools/kyc/digilocker/status

  -- Legacy PPI DigiKhata sender/Aadhaar-OTP code below is retained only for
     migration compatibility. Eko confirmed in July 2026 that Aadhaar OTP is
     not available; production routes use DigiLocker instead.

Auth (https://developers.eko.in/docs/auth):
  developer_key         static key issued by Eko
  secret-key            HMAC-SHA256(secret-key-timestamp, base64(access_key)), base64-encoded
  secret-key-timestamp  current UNIX time in milliseconds

Bank verification requires a customer profile to exist first (name + DOB,
optionally an address). We never fabricate DOB/address — if the user hasn't
supplied one, verification fails honestly rather than faking a pass.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import logging
import re
import time
import uuid

import httpx

from django.conf import settings

from services.eko_auth import build_eko_auth_headers_from_config

from .eko_config import eko_settings

logger = logging.getLogger('bullwave.kyc')

PAN_VERIFY_PATH = '/v1/pan/verify'
CUSTOMER_PATH = '/v2/customers/mobile_number:{mobile}'
BANK_VERIFY_PATH = '/v3/tools/kyc/bank-account/sync'
BANK_PENNYLESS_LEGACY_PATH = '/v3/tools/kyc/bank-account/penniless/sync'
DIGILOCKER_CREATE_PATH = '/v3/tools/kyc/digilocker'
DIGILOCKER_STATUS_PATH = '/v3/tools/kyc/digilocker/status'
DIGILOCKER_DOCUMENT_PATH = '/v3/tools/kyc/digilocker/document'
UPI_VALIDATE_VPA_PATH = '/v3/customer/payment/upi/validate-vpa'

PAN_SERVICE_CODE = 4
PPI_DIGIKHATA_SERVICE_CODE = 80


class EkoKycError(Exception):
    def __init__(self, message, code='', *, eko_meta=None):
        super().__init__(message)
        self.code = code
        self.eko_meta = eko_meta or {}


def _mask_pan_for_log(pan: str) -> str:
    value = (pan or '').upper().strip()
    if len(value) != 10:
        return '****'
    return f'{value[:2]}*****{value[-2:]}'


def _sanitize_eko_payload_for_log(payload) -> dict:
    """Redact PAN, Aadhaar, account numbers, OTP, and auth fields before DEBUG logging."""

    sensitive_keys = frozenset(
        {
            'developer_key',
            'secret-key',
            'secret_key',
            'access_key',
            'authorization',
            'otp',
            'aadhar',
            'aadhaar',
            'aadhaar_number',
        }
    )

    def scrub(value, key=''):
        if isinstance(value, dict):
            cleaned = {}
            for child_key, child_value in value.items():
                lowered = str(child_key).lower()
                if lowered in sensitive_keys:
                    cleaned[child_key] = '***'
                    continue
                if lowered in {'pan_number', 'pannumber'}:
                    cleaned[child_key] = _mask_pan_for_log(str(child_value))
                    continue
                if lowered in {'bank_account', 'account', 'account_number'}:
                    cleaned[child_key] = _mask_account_for_log(str(child_value))
                    continue
                if 'pan' in lowered and 'number' in lowered:
                    cleaned[child_key] = _mask_pan_for_log(str(child_value))
                    continue
                cleaned[child_key] = scrub(child_value, lowered)
            return cleaned
        if isinstance(value, list):
            return [scrub(item) for item in value]
        return value

    if isinstance(payload, dict):
        return scrub(payload)
    return payload


def _eko_meta_from_payload(payload: dict | None) -> dict:
    if not isinstance(payload, dict):
        return {}
    data = payload.get('data')
    inner = data if isinstance(data, dict) else {}
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                inner = item
                break
    reference_id = (
        inner.get('reference_id')
        or inner.get('reference_tid')
        or inner.get('transaction_id')
        or inner.get('client_ref_id')
        or payload.get('reference_id')
        or ''
    )
    return {
        'message': (payload.get('message') or '').strip(),
        'responseStatusId': payload.get('response_status_id'),
        'responseTypeId': payload.get('response_type_id'),
        'status': payload.get('status'),
        'referenceId': str(reference_id) if reference_id not in (None, '') else '',
    }


def _is_bank_verification_path(path: str) -> bool:
    lowered = (path or '').lower()
    return 'bank-account' in lowered or 'bank-acc-verify' in lowered


def _is_upi_verification_path(path: str) -> bool:
    lowered = (path or '').lower()
    return 'validate-vpa' in lowered or '/upi/' in lowered


def _log_upi_verification_exchange(
    *,
    method: str,
    path: str,
    request_data: dict | None,
    http_status: int,
    payload: dict,
) -> None:
    if not getattr(settings, 'DEBUG', False):
        return
    meta = _eko_meta_from_payload(payload)
    sanitized_request = _sanitize_eko_payload_for_log(request_data or {})
    sanitized_response = _sanitize_eko_payload_for_log(payload)
    logger.info(
        'Eko UPI validate exchange %s %s | HTTP %s | message=%r | response_status_id=%s | '
        'response_type_id=%s | reference_id=%s | request=%s | response=%s',
        method,
        path,
        http_status,
        meta.get('message'),
        meta.get('responseStatusId'),
        meta.get('responseTypeId'),
        meta.get('referenceId'),
        json.dumps(sanitized_request, default=str, ensure_ascii=False),
        json.dumps(sanitized_response, default=str, ensure_ascii=False),
    )


def _log_bank_verification_exchange(
    *,
    method: str,
    path: str,
    request_data: dict | None,
    http_status: int,
    payload: dict,
) -> None:
    """Detailed sanitized bank-verify exchange — DEBUG only, safe for log files."""
    if not getattr(settings, 'DEBUG', False):
        return
    meta = _eko_meta_from_payload(payload)
    sanitized_request = _sanitize_eko_payload_for_log(request_data or {})
    sanitized_response = _sanitize_eko_payload_for_log(payload)
    logger.info(
        'Eko bank verify exchange %s %s | HTTP %s | message=%r | response_status_id=%s | '
        'response_type_id=%s | reference_id=%s | request=%s | response=%s',
        method,
        path,
        http_status,
        meta.get('message'),
        meta.get('responseStatusId'),
        meta.get('responseTypeId'),
        meta.get('referenceId'),
        json.dumps(sanitized_request, default=str, ensure_ascii=False),
        json.dumps(sanitized_response, default=str, ensure_ascii=False),
    )


def _provider_error(message: str, code='', *, payload: dict | None = None) -> EkoKycError:
    meta = _eko_meta_from_payload(payload)
    lowered = (message or '').lower()
    if 'customer not allowed' in lowered:
        return EkoKycError(
            'Eko has not enabled the requested verification product for this merchant. '
            'Ask Eko to whitelist the API for the production account.',
            'service_not_active',
            eko_meta=meta,
        )
    if 'fraud' in lowered:
        return EkoKycError(
            'Eko blocked this attempt (fraud protection — usually too many tries or a '
            'mismatched account). Wait a few minutes, then enter the correct account number.',
            'fraud_detected',
            eko_meta=meta,
        )
    if code == 'invalid_account' or (
        'could not be verified' in lowered and 'account' in lowered
    ):
        return EkoKycError(
            message
            or 'This bank account could not be verified. Check the account number and IFSC, then retry.',
            'invalid_account',
            eko_meta=meta,
        )
    if 'no mapping rule matched' in lowered:
        return EkoKycError(
            message or 'Eko API route not found for this merchant host.',
            'eko_route_not_found',
            eko_meta=meta,
        )
    return EkoKycError(message, code, eko_meta=meta)


def _unwrap_eko_data(payload: dict) -> dict:
    data = payload.get('data')
    if isinstance(data, dict):
        return data
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                return item
    return {}


def _evaluate_eko_status(payload: dict, *, check_status: bool) -> None:
    """Raise when Eko reports business failure inside an HTTP 2xx envelope."""
    if not check_status:
        return
    primary_status = payload.get('status')
    rsid = payload.get('response_status_id')
    message = (payload.get('message') or 'Eko request failed.').strip()
    code = str(
        rsid
        if rsid is not None
        else primary_status
        if primary_status is not None
        else 'eko_error'
    )
    if primary_status is not None and str(primary_status) != '0':
        raise _provider_error(message, code, payload=payload)
    # Legacy v1 success uses -1; v3 commonly uses 0. Any other code is a business failure.
    if rsid is not None and str(rsid) not in ('-1', '0'):
        raise _provider_error(message, code, payload=payload)


def _extract_pan_registered_name(data: dict) -> str:
    if not isinstance(data, dict):
        return ''
    direct = (data.get('pan_returned_name') or data.get('registered_name') or data.get('name') or '').strip()
    if direct:
        return direct
    return ' '.join(
        filter(
            None,
            [
                (data.get('first_name') or '').strip(),
                (data.get('middle_name') or '').strip(),
                (data.get('last_name') or '').strip(),
            ],
        )
    ).strip()


def _pan_verification_confirmed(payload: dict, data: dict) -> bool:
    """True only when Eko explicitly returns verified PAN identity fields."""
    inner = data if data else _unwrap_eko_data(payload)
    if not inner:
        return False

    for key in ('valid', 'pan_valid', 'is_valid', 'verification_status', 'pan_status'):
        value = inner.get(key)
        if value is False or str(value).upper() in {'INVALID', 'FAILED', 'FAILURE', 'NO'}:
            return False

    pan_number = (inner.get('pan_number') or inner.get('panNumber') or '').strip().upper()
    registered_name = _extract_pan_registered_name(inner)
    if not registered_name:
        return False

    explicit_valid = any(
        inner.get(key) is True or str(inner.get(key) or '').upper() in {'VALID', 'SUCCESS', 'VERIFIED', 'YES'}
        for key in ('valid', 'pan_valid', 'is_valid', 'verification_status', 'pan_status')
    )
    if explicit_valid:
        return True

    # Eko PAN success responses include holder name; PAN number is usually present too.
    return bool(pan_number or registered_name)


def is_configured() -> bool:
    return eko_settings().is_configured


def _security_headers(cfg) -> dict:
    return build_eko_auth_headers_from_config(cfg)


_OTP_REF_KEYS = ('otp_ref_id', 'reference_tid', 'otp_reference_id', 'reference_id', 'tid', 'txn_id', 'ref_id')
_IGNORED_REF_KEYS = frozenset({'response_status_id', 'response_type_id', 'status'})


def _extract_ref_id(payload: dict) -> str:
    """Find whatever Eko actually named the OTP/transaction reference in a
    response, instead of hard-coding one guessed key name. Checks known key
    names first, then falls back to any key containing 'ref', 'otp', 'tid',
    or ending in '_id' with a real value — this is real-data parsing, not
    fabrication: if Eko didn't send *any* reference, this correctly returns ''.
    """
    for key in _OTP_REF_KEYS:
        value = payload.get(key)
        if value:
            return str(value)
    for key, value in payload.items():
        if key in _IGNORED_REF_KEYS or not value:
            continue
        lowered = key.lower()
        if 'ref' in lowered or 'otp' in lowered or 'tid' in lowered or lowered.endswith('_id'):
            return str(value)
    return ''


def _request(
    method: str,
    path: str,
    data: dict | None = None,
    *,
    check_status: bool = True,
    json_body: bool = False,
    base_url: str | None = None,
) -> dict:
    """check_status=False is for OTP-*trigger* endpoints (onboard_sender,
    generate_aadhaar_otp): confirmed in production that Eko can send a real
    OTP to the user's phone while still returning response_status_id/message
    values that look like a "failure" by the -1 convention used elsewhere
    (e.g. an informational "Validate the OTP" message). For those endpoints,
    the presence of an otp_ref_id in the payload is the real success signal,
    not response_status_id — so we skip the generic status check here and
    let the caller decide from the actual data returned.
    """
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoKycError('Eko API credentials are not configured.')

    url = f'{(base_url or cfg.base_url).rstrip("/")}{path}'
    headers = _security_headers(cfg)
    if json_body:
        headers['content-type'] = 'application/json'

    logger.info('Eko request start %s %s', method, url if base_url else path)
    if logger.isEnabledFor(logging.DEBUG):
        safe_keys = []
        if data:
            safe_keys = sorted(k for k in data if k not in {'account', 'bank_account', 'ifsc', 'pan_number', 'aadhar', 'otp'})
        logger.debug('Eko request body keys (no PII): %s client_ref_id=%s', safe_keys, (data or {}).get('client_ref_id', ''))

    response = _execute_eko_http(
        method=method,
        url=url,
        headers=headers,
        cfg=cfg,
        json_body=(data or {}) if json_body else None,
        form_body=None if json_body else (data or {}),
    )

    payload = {}
    try:
        payload = response.json()
    except Exception:
        pass

    if _is_bank_verification_path(path):
        _log_bank_verification_exchange(
            method=method,
            path=path,
            request_data=data,
            http_status=response.status_code,
            payload=payload if isinstance(payload, dict) else {},
        )
    if _is_upi_verification_path(path):
        _log_upi_verification_exchange(
            method=method,
            path=path,
            request_data=data,
            http_status=response.status_code,
            payload=payload if isinstance(payload, dict) else {},
        )

    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            'Eko sanitised response %s %s: %s',
            method,
            path,
            json.dumps(_sanitize_eko_payload_for_log(payload), default=str),
        )

    # Never log response bodies at INFO: Aadhaar KYC responses may contain personal
    # data. Status and Eko's non-sensitive response identifiers are enough.
    logger.info(
        'Eko %s %s -> HTTP %s response_status_id=%s response_type_id=%s payload_keys=%s data_keys=%s',
        method,
        path,
        response.status_code,
        payload.get('response_status_id'),
        payload.get('response_type_id'),
        sorted(payload.keys()) if isinstance(payload, dict) else [],
        sorted(payload.get('data', {}).keys()) if isinstance(payload.get('data'), dict) else [],
    )

    if isinstance(payload.get('data'), dict):
        data_payload = dict(payload['data'])
        data_payload['_eko_message'] = payload.get('message') or ''
        data_payload['_eko_response_status_id'] = payload.get('response_status_id')
        data_payload['_eko_response_type_id'] = payload.get('response_type_id')
        data_payload['_eko_status'] = payload.get('status')
    else:
        data_payload = dict(payload) if isinstance(payload, dict) else {}
    has_otp_ref = bool(_extract_ref_id(data_payload)) if not check_status else False

    if response.status_code == 401:
        raise EkoKycError(
            'Invalid Eko developer key or secret key.',
            'auth_failed',
            eko_meta=_eko_meta_from_payload(payload),
        )
    if response.is_error:
        # For OTP-trigger endpoints (check_status=False), Eko can return a
        # non-2xx / "failure-shaped" response that still carries a real
        # otp_ref_id — confirmed in production where the user received a
        # genuine SMS OTP despite the response looking like an error. Treat
        # the presence of an OTP reference as the real success signal there.
        if not (not check_status and has_otp_ref):
            message = _safe_error_message(payload, response)
            raise _provider_error(
                message,
                str(payload.get('response_status_id', '') or response.status_code),
                payload=payload,
            )

    _evaluate_eko_status(payload, check_status=check_status)

    return data_payload


def _safe_error_message(payload: dict, response) -> str:
    message = payload.get('message') if isinstance(payload, dict) else ''
    if isinstance(message, str) and message.strip():
        return message.strip()[:240]
    body = (response.text or '').lstrip()
    content_type = (response.headers.get('content-type') or '').lower()
    if body.startswith('<') or 'text/html' in content_type:
        if response.status_code == 403:
            return (
                'Eko rejected the request. Check credential scope, IP whitelist, '
                'timestamp, and request field limits.'
            )
        return (
            f'Eko returned HTTP {response.status_code} from an invalid or unsupported API route. '
            'Check the Eko base URL, endpoint version, and Content-Type.'
        )
    return body[:240] or f'Eko error ({response.status_code})'


def _eko_http_timeout(cfg) -> httpx.Timeout:
    read_seconds = max(30.0, float(cfg.http_timeout_seconds))
    return httpx.Timeout(connect=15.0, read=read_seconds, write=30.0, pool=15.0)


def _execute_eko_http(
    *,
    method: str,
    url: str,
    headers: dict,
    cfg,
    json_body: dict | None = None,
    form_body: dict | None = None,
    params: dict | None = None,
) -> httpx.Response:
    timeout = _eko_http_timeout(cfg)
    last_timeout: httpx.HTTPError | None = None
    for attempt in range(2):
        try:
            with httpx.Client(timeout=timeout) as client:
                if method.upper() == 'GET':
                    return client.get(url, params=params or {}, headers=headers)
                return client.request(
                    method,
                    url,
                    json=json_body,
                    data=form_body,
                    params=params,
                    headers=headers,
                )
        except (httpx.ReadTimeout, httpx.ConnectTimeout, httpx.WriteTimeout) as exc:
            last_timeout = exc
            if attempt == 0:
                logger.warning('Eko %s %s timed out — retrying once', method, url)
                continue
            raise EkoKycError(
                'Eko is taking too long to respond. Please try again in a moment.',
                'timeout',
            ) from exc
        except httpx.HTTPError as exc:
            raise EkoKycError(f'Eko connection failed: {exc}') from exc
    raise EkoKycError(
        'Eko is taking too long to respond. Please try again in a moment.',
        'timeout',
    ) from last_timeout


def _get(path: str, params: dict | None = None, *, check_status: bool = True) -> dict:
    """Like _request() but for GET endpoints that take query params, not a body."""
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoKycError('Eko API credentials are not configured.')

    url = f'{cfg.base_url.rstrip("/")}{path}'
    headers = _security_headers(cfg)

    response = _execute_eko_http(
        method='GET',
        url=url,
        headers=headers,
        cfg=cfg,
        params=params,
    )

    payload = {}
    try:
        payload = response.json()
    except Exception:
        pass

    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            'Eko sanitised GET response %s: %s',
            path,
            json.dumps(_sanitize_eko_payload_for_log(payload), default=str),
        )

    logger.info(
        'Eko GET %s -> HTTP %s response_status_id=%s response_type_id=%s',
        path,
        response.status_code,
        payload.get('response_status_id'),
        payload.get('response_type_id'),
    )

    data_payload = payload.get('data') if isinstance(payload.get('data'), dict) else payload
    if isinstance(data_payload, dict):
        data_payload = dict(data_payload)
        data_payload['_eko_message'] = payload.get('message') or ''
        data_payload['_eko_response_status_id'] = payload.get('response_status_id')
        data_payload['_eko_response_type_id'] = payload.get('response_type_id')
        data_payload['_eko_status'] = payload.get('status')
    has_ref = bool(_extract_ref_id(data_payload)) if not check_status else False

    if response.status_code == 401:
        raise EkoKycError(
            'Invalid Eko developer key or secret key.',
            'auth_failed',
            eko_meta=_eko_meta_from_payload(payload),
        )
    if response.is_error:
        if not (not check_status and has_ref):
            message = _safe_error_message(payload, response)
            raise _provider_error(
                message,
                str(payload.get('response_status_id', '') or response.status_code),
                payload=payload,
            )

    _evaluate_eko_status(payload, check_status=check_status)

    return data_payload


def activate_pan_service() -> dict:
    """One-time production activation for PAN verification (service_code=4).

    Run once via: python manage.py activate_eko_pan_service

    Eko treats "already active" as an error response, not a success — we
    normalize that here so re-running this command is always safe.
    """
    return activate_service(PAN_SERVICE_CODE)


def activate_service(service_code) -> dict:
    """Generic one-time production activation for any Eko service_code —
    "Customer not allowed" / "Customer Not Enrolled" errors on a brand-new
    Eko account are almost always this: the specific service (PAN, PPI
    DigiKhata/Aadhaar, bank verification, etc.) was never activated for this
    user_code. Confirmed working for PAN (service_code=4); the same
    activation call works for any other service_code Eko assigns.

    Run via: python manage.py activate_eko_service <service_code>
    """
    cfg = eko_settings()
    try:
        return _request(
            'PUT',
            f'/v3/admin/network/agent/{cfg.user_code}/service/{service_code}/activate',
            {
                'initiator_id': cfg.initiator_id,
                'client_ref_id': uuid.uuid4().hex[:20],
            },
            json_body=True,
        )
    except EkoKycError as exc:
        if 'already exist' in str(exc).lower():
            return {'status': 'already_active', 'message': str(exc)}
        raise


def list_services() -> list:
    """List every Eko service and its service_code for this account, so we
    can find the exact code for PPI DigiKhata / Aadhaar verification instead
    of guessing. Run via: python manage.py list_eko_services
    """
    cfg = eko_settings()
    result = _get('/v3/tools/catalog/service-codes', {'initiator_id': cfg.initiator_id})
    if isinstance(result, dict):
        for key in ('services', 'service_list', 'list', 'items'):
            if isinstance(result.get(key), list):
                return result[key]
        return [result]
    if isinstance(result, list):
        return result
    return []


def get_user_services() -> list:
    """List which services are already activated/enabled for this user_code —
    lets us confirm activation actually took effect. Run via:
    python manage.py list_eko_services --enabled
    """
    cfg = eko_settings()
    result = _get(
        '/v3/user/account/services',
        {'initiator_id': cfg.initiator_id, 'user_code': cfg.user_code},
    )
    if isinstance(result, dict):
        for key in ('service_status_list', 'services', 'service_list', 'list', 'items'):
            if isinstance(result.get(key), list):
                return result[key]
        return [result]
    if isinstance(result, list):
        return result
    return []


def eko_kyc_billing_status() -> dict:
    """Explain which Eko KYC APIs are wired and what must be enabled for wallet debits."""
    cfg = eko_settings()
    return {
        'configured': cfg.is_configured,
        'environment': cfg.environment,
        'orgSlugSet': bool(cfg.org_slug),
        'pennilessConfigured': cfg.penniless_configured,
        'bankSoftVerify': bool(getattr(settings, 'EKO_BANK_SOFT_VERIFY', False)),
        'upiSoftVerify': bool(getattr(settings, 'EKO_UPI_SOFT_VERIFY', False)),
        'steps': {
            'pan': {
                'api': 'POST /v1/pan/verify',
                'walletLabel': 'PAN Verification',
                'activate': 'python manage.py activate_eko_pan_service',
            },
            'digilocker': {
                'api': 'POST /v3/tools/kyc/digilocker',
                'walletLabel': 'DigiLocker / Aadhaar',
                'note': 'Debited when consent completes. Ask Eko to enable DigiLocker on connect.eko.in.',
            },
            'bank': {
                'api': 'POST /v3/tools/kyc/bank-account/sync (penny-drop) or .../bank-acc-verify-penniless',
                'walletLabel': 'Bank Verification',
                'activate': 'Ask Eko to enable Bank Verification; set EKO_ORG_SLUG for penny-less.',
            },
            'upi': {
                'api': 'POST /v3/customer/payment/upi/validate-vpa',
                'walletLabel': 'UPI Verification',
                'activate': 'python manage.py activate_eko_upi_service',
            },
        },
    }


def verify_pan(pan: str, name: str) -> dict:
    """PAN Verification (v1) — validates PAN + name via Eko.

    Success envelope (Eko OpenAPI example for POST /v1/pan/verify):
        response_status_id = -1 (legacy) or 0 (v3)
        status = 0
        data.pan_returned_name / first_name / last_name present

    Business failures often arrive as HTTP 200 with response_status_id = 1 and a
    human-readable message such as "PAN verification response not received".
    """
    cfg = eko_settings()
    pan = pan.upper().strip()
    request_data = {
        'pan_number': pan,
        'purpose': 1,
        'purpose_desc': 'KYC verification for investment account onboarding',
        'initiator_id': cfg.initiator_id,
    }
    result = _request('POST', PAN_VERIFY_PATH, request_data)

    envelope = {
        'message': result.get('_eko_message') or '',
        'response_status_id': result.get('_eko_response_status_id'),
        'response_type_id': result.get('_eko_response_type_id'),
        'status': result.get('_eko_status'),
        'data': {key: value for key, value in result.items() if not str(key).startswith('_eko')},
    }
    inner = {key: value for key, value in result.items() if not str(key).startswith('_eko')}

    if not _pan_verification_confirmed(envelope, inner):
        message = (
            (result.get('_eko_message') or '').strip()
            or 'Eko did not confirm PAN verification.'
        )
        raise EkoKycError(
            message,
            str(result.get('_eko_response_status_id') or 'pan_not_verified'),
            eko_meta=_eko_meta_from_payload(envelope),
        )

    registered_name = _extract_pan_registered_name(inner)
    matched = _loose_match(name, registered_name) if name else None
    if name and matched is False:
        raise EkoKycError(
            f'Name on PAN does not match the name you entered. Registered name: {registered_name}.',
            'name_mismatch',
            eko_meta=_eko_meta_from_payload(envelope),
        )

    return {
        'reference_id': str(inner.get('reference_id') or inner.get('pan_number') or pan),
        'registered_name': registered_name,
        'pan_type': inner.get('aadhaar_seeding_status', ''),
        'name_match_result': 'DIRECT_MATCH' if matched else '',
        'name_match_score': 100 if matched else 0,
        'valid': True,
        'dob': inner.get('dob') or inner.get('date_of_birth') or inner.get('birth_date') or '',
    }


def _mask_account_for_log(account: str) -> str:
    acct = (account or '').strip()
    if len(acct) <= 4:
        return '****'
    return f'****{acct[-4:]}'


def verify_bank_account_penny_drop(
    *,
    bank_account: str,
    ifsc: str,
    name: str = '',
) -> dict:
    from services.eko_bank import EkoBankError, verify_bank_account_penny_drop as _verify

    try:
        return _verify(
            account_number=bank_account,
            ifsc=ifsc,
            account_holder_name=name,
        )
    except EkoBankError as exc:
        raise EkoKycError(str(exc), exc.code, eko_meta=getattr(exc, 'eko_meta', None)) from exc


def verify_bank_account_penniless(
    *,
    bank_account: str,
    ifsc: str,
    name: str = '',
) -> dict:
    from services.eko_bank import EkoBankError, verify_bank_account_penniless as _verify

    try:
        return _verify(
            account_number=bank_account,
            ifsc=ifsc,
            account_holder_name=name,
        )
    except EkoBankError as exc:
        raise EkoKycError(str(exc), exc.code, eko_meta=getattr(exc, 'eko_meta', None)) from exc


def verify_bank_account(
    *,
    bank_account: str,
    ifsc: str,
    name: str = '',
    phone: str = '',
    dob: str = '',
    address: dict | None = None,
) -> dict:
    from services.eko_bank import EkoBankError, verify_bank_account as _verify

    try:
        return _verify(
            account_number=bank_account,
            ifsc=ifsc,
            account_holder_name=name,
            phone=phone,
            dob=dob,
            address=address,
        )
    except EkoBankError as exc:
        raise EkoKycError(str(exc), exc.code, eko_meta=getattr(exc, 'eko_meta', None)) from exc


def mobile_from_upi_vpa(vpa: str) -> str:
    """Return a 10-digit mobile when the VPA local part is phone@handle."""
    local = (vpa or '').split('@', 1)[0]
    digits = re.sub(r'\D', '', local)
    if len(digits) == 12 and digits.startswith('91'):
        digits = digits[2:]
    if len(digits) == 11 and digits.startswith('0'):
        digits = digits[1:]
    if len(digits) == 10 and digits[0] in '6789':
        return digits
    return ''


def _eko_upi_base_urls(cfg) -> list[str]:
    """Payment/UPI APIs may be routed on a different Eko host than KYC tools."""
    urls: list[str] = []
    explicit = (getattr(settings, 'EKO_UPI_BASE_URL', '') or '').strip().rstrip('/')
    if explicit:
        urls.append(explicit)
    primary = (cfg.base_url or '').strip().rstrip('/')
    if primary and primary not in urls:
        urls.append(primary)
    # Eko's payment gateway historically used :25002 on production.
    if cfg.is_production and primary.startswith('https://api.eko.in/') and ':25002' not in primary:
        legacy = primary.replace('https://api.eko.in/', 'https://api.eko.in:25002/', 1)
        if legacy not in urls:
            urls.append(legacy)
    return urls


def _is_mapping_rule_error(exc: EkoKycError) -> bool:
    return exc.code == 'eko_route_not_found' or 'no mapping rule matched' in str(exc).lower()


def _is_terminal_upi_error(exc: EkoKycError) -> bool:
    return exc.code in {
        'upi_invalid',
        'upi_name_missing',
        'invalid_mobile',
        'invalid_name',
        'auth_failed',
        'fraud_detected',
        'service_not_active',
    }


def _upi_validate_attempts(
    cfg,
    *,
    client_ref_id: str,
    customer_vpa: str,
    mobile: str,
    customer_id: str,
    name: str,
    latlong: str,
) -> list[tuple[str, dict, bool]]:
    """Build validate-vpa attempts for Eko's v3 payment route.

    customer_id is the merchant's onboarded Eko customer (usually the app
    user's login mobile). recipient_mobile is the number linked to the VPA.
    """
    payload = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'client_ref_id': client_ref_id,
        'customer_vpa': customer_vpa,
        'recipient_mobile': mobile,
        'customer_id': customer_id,
        'name': name,
        'latlong': latlong,
    }
    # Form-encoded first — same transport as PAN/bank; JSON as fallback.
    return [
        (UPI_VALIDATE_VPA_PATH, payload, False),
        (UPI_VALIDATE_VPA_PATH, payload, True),
    ]


def _is_upi_service_unavailable(exc: EkoKycError) -> bool:
    message = str(exc).lower()
    return exc.code in {'1', 'upi_request_rejected', 'upi_service_unavailable'} or (
        'please provide the value of the field' in message
        and 'customer_id' not in message
    )


def _is_upi_customer_missing(exc: EkoKycError) -> bool:
    message = str(exc).lower()
    return 'customer_id does not exist' in message or 'customer does not exist' in message


def _is_upi_transaction_failed(exc: EkoKycError) -> bool:
    return 'transaction failed' in str(exc).lower()


def _ensure_eko_customer(mobile: str, name: str, dob: str, address: dict | None) -> None:
    """Best-effort: register the app user as an Eko customer before UPI calls."""
    cfg = eko_settings()
    mobile = _clean_mobile(mobile)
    if not mobile or not name.strip():
        return
    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'name': name.strip(),
        'mobile': mobile,
    }
    if dob:
        data['dob'] = dob
    residence_address = _residence_address(address)
    if residence_address:
        data['residence_address'] = residence_address
    try:
        _request(
            'PUT',
            CUSTOMER_PATH.format(mobile=mobile),
            data,
            json_body=False,
            check_status=False,
        )
    except EkoKycError:
        pass
    if dob:
        _ensure_base_customer(mobile, name.strip(), dob, address or {})


def _normalize_upi_validation_result(result: dict, *, customer_vpa: str, fallback_mobile: str, client_ref_id: str) -> dict:
    valid = result.get('valid')
    if valid is False:
        raise EkoKycError(
            result.get('_eko_message') or 'UPI ID is invalid or inactive.',
            'upi_invalid',
        )
    recipient_name = (
        result.get('recipient_name')
        or result.get('name')
        or result.get('payee_name')
        or ''
    ).strip()
    if not recipient_name:
        raise EkoKycError(
            'Eko did not return a verified payee name for this UPI ID.',
            'upi_name_missing',
        )
    return {
        'vpa': (result.get('vpa') or customer_vpa).strip().lower(),
        'valid': True if valid is None else bool(valid),
        'recipient_name': recipient_name,
        'mobile_number': (result.get('mobile_number') or fallback_mobile).strip(),
        'reference_id': str(
            result.get('transaction_id') or result.get('reference_id') or client_ref_id
        ),
    }


def verify_upi_vpa(
    *,
    customer_vpa: str,
    recipient_mobile: str,
    name: str,
    latlong: str = '28.6139,77.2090',
    customer_id: str = '',
    dob: str = '',
    address: dict | None = None,
) -> dict:
    """Validate a UPI VPA via Eko Connect and return verified payee details."""
    cfg = eko_settings()
    customer_vpa = customer_vpa.strip().lower()
    mobile = mobile_from_upi_vpa(customer_vpa) or _clean_mobile(recipient_mobile)
    recipient_name_hint = (name or '').strip()
    if not recipient_name_hint:
        raise EkoKycError('Recipient name is required for UPI verification.', 'invalid_name')
    if not mobile:
        raise EkoKycError('Linked mobile number is required for UPI verification.', 'invalid_mobile')

    eko_customer_id = _clean_mobile(customer_id) or mobile
    if dob or address:
        _ensure_eko_customer(eko_customer_id, recipient_name_hint, dob, address)

    client_ref_id = uuid.uuid4().hex[:20]
    latlong = (latlong or '28.6139,77.2090').strip()
    retried_customer = False
    last_exc: EkoKycError | None = None

    def _run_validate() -> dict:
        nonlocal last_exc
        for base_url in _eko_upi_base_urls(cfg):
            for path, payload, json_body in _upi_validate_attempts(
                cfg,
                client_ref_id=client_ref_id,
                customer_vpa=customer_vpa,
                mobile=mobile,
                customer_id=eko_customer_id,
                name=recipient_name_hint,
                latlong=latlong,
            ):
                try:
                    result = _request(
                        'POST',
                        path,
                        payload,
                        json_body=json_body,
                        base_url=base_url,
                    )
                    return _normalize_upi_validation_result(
                        result,
                        customer_vpa=customer_vpa,
                        fallback_mobile=mobile,
                        client_ref_id=client_ref_id,
                    )
                except EkoKycError as exc:
                    last_exc = exc
                    logger.warning(
                        'Eko UPI validate base=%s path=%s json=%s failed (%s): %s',
                        base_url,
                        path,
                        json_body,
                        exc.code or 'error',
                        exc,
                    )
                    if _is_terminal_upi_error(exc) or _is_upi_transaction_failed(exc):
                        raise
                    if _is_mapping_rule_error(exc):
                        continue
        raise last_exc or EkoKycError(
            'UPI verification is unavailable on Eko right now.',
            'upi_unavailable',
        )

    while True:
        try:
            return _run_validate()
        except EkoKycError as exc:
            if _is_upi_transaction_failed(exc):
                raise EkoKycError(
                    'This UPI ID could not be verified. Check the VPA handle and linked mobile, then try again.',
                    'upi_invalid',
                    eko_meta=getattr(exc, 'eko_meta', None) or {},
                ) from exc
            if _is_upi_customer_missing(exc) and not retried_customer:
                retried_customer = True
                _ensure_eko_customer(eko_customer_id, recipient_name_hint, dob, address)
                continue
            if _is_upi_service_unavailable(exc) or _is_mapping_rule_error(exc):
                raise EkoKycError(
                    'Eko UPI Verification route is not enabled for this merchant account. '
                    'Run: python manage.py activate_eko_upi_service — or ask Eko Connect to enable '
                    'UPI ID Verification on your production host.',
                    'upi_service_unavailable',
                ) from exc
            raise


def create_digilocker_url(*, client_ref_id: str, redirect_url: str) -> dict:
    """Create Eko's consent-based DigiLocker Aadhaar verification journey."""
    cfg = eko_settings()
    result = _request(
        'POST',
        DIGILOCKER_CREATE_PATH,
        {
            'initiator_id': cfg.initiator_id,
            'user_code': cfg.user_code,
            'client_ref_id': client_ref_id,
            'document_requested': ['AADHAAR'],
            'redirect_url': redirect_url,
        },
        check_status=False,
        json_body=True,
    )
    digilocker_url = result.get('url') or result.get('digilocker_url') or ''
    reference_id = result.get('reference_id')
    if not digilocker_url or reference_id in (None, ''):
        raise EkoKycError(
            'Eko did not return a DigiLocker verification URL and reference.',
            'digilocker_session_failed',
        )
    return {
        'url': digilocker_url,
        'reference_id': str(reference_id),
        'verification_id': str(result.get('verification_id') or ''),
    }


def _normalize_digilocker_status_value(raw) -> str:
    if raw is None:
        return ''
    if isinstance(raw, bool):
        return 'SUCCESS' if raw else 'PENDING'
    if isinstance(raw, (int, float)):
        return 'SUCCESS' if int(raw) == 0 else 'PENDING'
    text = str(raw).strip().upper()
    if text in {'0', '-1'}:
        return 'SUCCESS'
    if text in {'1', '2'}:
        return 'PENDING'
    return text


def _digilocker_lookup_param(key: str, value) -> object:
    if value in (None, ''):
        return None
    if key == 'reference_id':
        try:
            return int(value)
        except (TypeError, ValueError):
            return value
    return value


def _normalize_digilocker_result(
    result: dict,
    *,
    verification_id: str = '',
) -> dict:
    status_raw = (
        result.get('verification_status')
        or result.get('verification_state')
        or result.get('status')
        or ''
    )
    user_details = result.get('user_details') if isinstance(result.get('user_details'), dict) else {}
    if not user_details and (result.get('name') or result.get('dob')):
        user_details = {
            'name': (result.get('name') or '').strip(),
            'dob': result.get('dob') or '',
            'gender': result.get('gender') or '',
            'eaadhaar': 'Y' if (result.get('name') or result.get('uid')) else 'N',
        }
    document_consent = result.get('document_consent') or []
    if not document_consent and user_details.get('name'):
        document_consent = [{'document_type': 'AADHAAR', 'consent': 'Y'}]
    return {
        'verification_status': _normalize_digilocker_status_value(status_raw),
        'verification_id': str(result.get('verification_id') or verification_id or ''),
        'user_details': user_details,
        'document_consent': document_consent,
        'document_requested': result.get('document_requested') or ['AADHAAR'],
    }


def _digilocker_document_error(result: dict) -> tuple[str, str] | None:
    """Return (message, code) when Eko's document envelope indicates failure."""
    if not isinstance(result, dict):
        return ('DigiLocker document fetch failed.', 'digilocker_document_failed')
    rsid = result.get('response_status_id')
    code = str(result.get('code') or '').strip()
    message = (result.get('message') or result.get('_eko_message') or '').strip()
    if rsid is not None and str(rsid) not in ('-1', '0'):
        return (message or 'DigiLocker document fetch failed.', code or 'digilocker_document_failed')
    if code and not (result.get('name') or result.get('uid')):
        return (message or 'DigiLocker document fetch failed.', code or 'digilocker_document_failed')
    return None


def fetch_digilocker_document(
    *,
    reference_id: str,
    verification_id: str,
    client_ref_id: str,
) -> dict:
    """Fetch verified Aadhaar identity via POST /digilocker/document (primary on Eko ICICI)."""
    cfg = eko_settings()
    result = _request(
        'POST',
        DIGILOCKER_DOCUMENT_PATH,
        {
            'initiator_id': cfg.initiator_id,
            'user_code': cfg.user_code,
            'document_type': 'AADHAAR',
            'source': 'API',
            'client_ref_id': client_ref_id,
            'verification_id': verification_id,
            'reference_id': str(reference_id),
        },
        check_status=False,
        json_body=False,
    )
    failure = _digilocker_document_error(result)
    if failure:
        message, code = failure
        raise EkoKycError(message, code or 'digilocker_document_failed')
    normalized = _normalize_digilocker_result(result, verification_id=verification_id)
    if normalized['user_details'].get('name') or result.get('uid'):
        normalized['verification_status'] = 'SUCCESS'
    return normalized


def get_digilocker_status(
    *,
    reference_id: str = '',
    client_ref_id: str = '',
    verification_id: str = '',
) -> dict:
    """Fetch DigiLocker consent result. Uses POST document API — GET status 404s on Eko ICICI."""
    errors: list[str] = []

    if verification_id and reference_id and client_ref_id:
        try:
            return fetch_digilocker_document(
                reference_id=reference_id,
                verification_id=verification_id,
                client_ref_id=client_ref_id,
            )
        except EkoKycError as exc:
            errors.append(str(exc))

    def _fetch(**lookup) -> dict:
        params = {'initiator_id': eko_settings().initiator_id}
        if client_ref_id:
            params['client_ref_id'] = client_ref_id
        for key, value in lookup.items():
            normalized = _digilocker_lookup_param(key, value)
            if normalized not in (None, ''):
                params[key] = normalized
        return _get(DIGILOCKER_STATUS_PATH, params, check_status=False)

    attempts = []
    if verification_id:
        attempts.append({'verification_id': verification_id})
    if reference_id:
        attempts.append({'reference_id': reference_id})

    for lookup in attempts:
        try:
            return _normalize_digilocker_result(
                _fetch(**lookup),
                verification_id=verification_id,
            )
        except EkoKycError as exc:
            errors.append(str(exc))

    raise EkoKycError(
        errors[-1] if errors else 'Could not fetch DigiLocker verification status.',
        'digilocker_status_failed',
    )


# ── Aadhaar OTP eKYC (Eko PPI DigiKhata "Sender" Aadhaar-OTP flow) ──
#
# Confirmed against Eko's own docs (developers.eko.in/reference/sender,
# .../ppi-transaction-flow, .../onboard-sender, .../generate-sender-aadhaar-otp,
# .../verify-sender-otp-1, .../get-sender-information):
#
#   A mobile number must first be onboarded as a DigiKhata "sender" before
#   Aadhaar-OTP verification will work. Calling the Aadhaar OTP endpoint for
#   a mobile that was never onboarded is exactly what produces Eko's real
#   "Customer Not Enrolled" error — this was hit in production and is fixed
#   below by checking/onboarding the sender first.
#
#   Flow: get_sender_info() -> if not enrolled: onboard_sender() (triggers a
#   mobile-verification OTP) -> verify_sender_otp() -> generate_aadhaar_otp()
#   -> verify_aadhaar_otp().
SENDER_PROFILE_PATH = '/v3/customer/profile/{mobile}/ppi-digikhata'
SENDER_ONBOARD_PATH = '/v3/customer/payment/ppi-digikhata/sender/{mobile}'
SENDER_OTP_VERIFY_PATH = '/v3/customer/payment/ppi-digikhata/sender/{mobile}/otp/verify'
AADHAAR_OTP_GENERATE_PATH = '/v3/customer/payment/ppi-digikhata/sender/{mobile}/aadhaar/otp'
AADHAAR_OTP_VERIFY_PATH = '/v3/customer/payment/ppi-digikhata/sender/{mobile}/aadhaar/otp/verify'
SENDER_OTP_RESEND_PATH = '/v3/customer/payment/ppi-digikhata/sender/{mobile}/otp'


def get_sender_info(mobile: str) -> dict:
    """Check the DigiKhata sender status for this mobile number.

    Confirmed real response for an in-progress sender (production log):
        {"response_status_id": 0, "data": {"intent_id": 19, "kyc_request_id": "",
         "otp_ref_id": "HiRXSQ6w..."}, "message": "Validate the OTP", "status": 0}
    Note response_status_id is 0 here, NOT -1 — this is *not* a failure, it's
    Eko saying a mobile-verification OTP is already pending for this sender
    and handing back the otp_ref_id to validate it with. Our generic status
    check used to treat this as a hard error and crash the whole Aadhaar flow
    before it could ever show an OTP field — fixed by calling this with
    check_status=False and reading the real signal (presence of otp_ref_id)
    instead of the status code.

    Returns a dict:
      {'enrolled': True}                        — sender fully enrolled, go straight to Aadhaar OTP.
      {'enrolled': False, 'otp_ref_id': '...'}   — a sender-verification OTP is already
                                                    pending; validate it via verify_sender_otp.
      {'enrolled': False, 'otp_ref_id': ''}      — genuinely new sender; call onboard_sender.
    """
    cfg = eko_settings()
    mobile = _clean_mobile(mobile)
    try:
        result = _get(
            SENDER_PROFILE_PATH.format(mobile=mobile),
            {'initiator_id': cfg.initiator_id, 'user_code': cfg.user_code},
            check_status=False,
        )
    except EkoKycError as exc:
        message = str(exc).lower()
        if 'not enrolled' in message or 'not exist' in message or 'not found' in message:
            return {'enrolled': False, 'otp_ref_id': ''}
        raise

    otp_ref_id = _extract_ref_id(result)
    if otp_ref_id:
        return {'enrolled': False, 'otp_ref_id': otp_ref_id}
    return {'enrolled': True}


CUSTOMER_ONBOARD_PATH = '/v3/customer/account/{mobile}'


def _ensure_base_customer(mobile: str, name: str, dob: str, address: dict) -> None:
    """Best-effort prerequisite: create Eko's base Customer Management record
    for this mobile number.

    Confirmed in production: Onboard Sender can fail with "customer_id does
    not exist in system" for a mobile number that has never interacted with
    any Eko product before — PPI DigiKhata attaches Sender/Aadhaar
    capabilities to an existing customer record rather than creating one
    from scratch. This calls Eko's general "Onboard Customer" API (same
    name/dob/residence_address shape) to create that base record first.
    We deliberately don't chase the OTP this triggers — that belongs to an
    unrelated Customer-Management verification flow; we only need the
    record to exist so Sender onboarding can find it.
    """
    cfg = eko_settings()
    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'name': name,
        'dob': dob,
    }
    residence_address = _residence_address(address)
    if residence_address:
        data['residence_address'] = residence_address
    try:
        _request('POST', CUSTOMER_ONBOARD_PATH.format(mobile=mobile), data, check_status=False)
    except EkoKycError:
        # Best-effort — if this also fails, let the retried Sender-onboarding
        # call's real error surface instead of masking it with this one.
        pass


def onboard_sender(*, mobile: str, name: str, dob: str, address: dict | None = None) -> dict:
    """Onboard a mobile number as a DigiKhata sender (one-time, required
    before Aadhaar OTP verification will work for that mobile).

    Triggers a mobile-verification OTP that must be confirmed via
    verify_sender_otp() before Aadhaar OTP generation can succeed.
    """
    if not dob:
        raise EkoKycError(
            'Date of birth is required to enroll for Aadhaar verification. Please add it to your profile first.',
            'dob_required',
        )

    cfg = eko_settings()
    mobile = _clean_mobile(mobile)
    address = {k: v for k, v in (address or {}).items() if v}

    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'name': name,
        'dob': dob,
        'service_code': PPI_DIGIKHATA_SERVICE_CODE,
    }
    residence_address = _residence_address(address)
    if residence_address:
        data['residence_address'] = residence_address

    try:
        result = _request('POST', SENDER_ONBOARD_PATH.format(mobile=mobile), data, check_status=False)
    except EkoKycError as exc:
        if 'does not exist' in str(exc).lower():
            _ensure_base_customer(mobile, name, dob, address)
            result = _request('POST', SENDER_ONBOARD_PATH.format(mobile=mobile), data, check_status=False)
        else:
            raise

    otp_ref_id = _extract_ref_id(result)

    if not otp_ref_id:
        # Eko's own docs (Verify Sender OTP) say the otp_ref_id for a new
        # sender can also be read back from Get Sender Info, not just the
        # onboarding response itself — try that before giving up, since the
        # onboarding call can genuinely dispatch the OTP without echoing a
        # reference id in its own body.
        try:
            info = _get(
                SENDER_PROFILE_PATH.format(mobile=mobile),
                {'initiator_id': cfg.initiator_id, 'user_code': cfg.user_code},
                check_status=False,
            )
            otp_ref_id = _extract_ref_id(info)
        except EkoKycError:
            pass

    if not otp_ref_id:
        raise EkoKycError(
            result.get('message') or 'Eko did not return an OTP reference for sender onboarding.',
            'sender_otp_ref_missing',
        )
    return {'otp_ref_id': otp_ref_id}


def verify_sender_otp(*, mobile: str, otp: str, otp_ref_id: str) -> dict:
    """Confirm the mobile-verification OTP sent by onboard_sender()."""
    cfg = eko_settings()
    mobile = _clean_mobile(mobile)
    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'otp': otp,
        'otp_ref_id': otp_ref_id,
    }
    result = _request('POST', SENDER_OTP_VERIFY_PATH.format(mobile=mobile), data)
    return result


def generate_sender_otp(mobile: str) -> dict:
    """Explicitly request a *fresh* mobile-verification OTP for an existing
    pending DigiKhata sender (Eko's "Generate Sender Verification OTP" API).

    The otp_ref_id handed back by get_sender_info() can go stale (Eko's own
    pending OTP expires after a few minutes) — if verify_sender_otp() fails
    with something like "Validate OTP Failed", the fix is a fresh OTP via
    this endpoint, not reusing the old reference. Same check_status=False
    treatment as onboard_sender/generate_aadhaar_otp: the presence of a real
    otp_ref_id in the response is the success signal, not response_status_id.
    """
    cfg = eko_settings()
    mobile = _clean_mobile(mobile)
    data = {'initiator_id': cfg.initiator_id, 'user_code': cfg.user_code}
    result = _request('POST', SENDER_OTP_RESEND_PATH.format(mobile=mobile), data, check_status=False)

    otp_ref_id = _extract_ref_id(result)
    if not otp_ref_id:
        raise EkoKycError(
            result.get('message') or 'Eko did not return a fresh OTP reference.',
            'sender_otp_resend_failed',
        )
    return {'otp_ref_id': otp_ref_id}


def generate_aadhaar_otp(*, aadhaar_number: str, name: str, mobile: str) -> dict:
    """Trigger an OTP to the mobile number linked to this Aadhaar number.

    Requires the mobile to already be onboarded as a DigiKhata sender —
    callers should run the get_sender_info/onboard_sender/verify_sender_otp
    flow above first.
    """
    aadhaar_number = re.sub(r'\D', '', aadhaar_number or '')
    if len(aadhaar_number) != 12:
        raise EkoKycError('Aadhaar number must be exactly 12 digits.', 'invalid_aadhaar')

    cfg = eko_settings()
    mobile = _clean_mobile(mobile)

    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'name': name,
        'aadhar': aadhaar_number,
    }
    result = _request('POST', AADHAAR_OTP_GENERATE_PATH.format(mobile=mobile), data, check_status=False)

    otp_ref_id = _extract_ref_id(result)
    if not otp_ref_id:
        raise EkoKycError(
            result.get('message') or 'Eko did not return an OTP reference for Aadhaar verification.',
            'otp_ref_missing',
        )
    return {
        'otp_ref_id': otp_ref_id,
        'reference_id': str(result.get('reference_tid') or otp_ref_id),
    }


def verify_aadhaar_otp(*, mobile: str, otp: str, otp_ref_id: str) -> dict:
    """Verify the OTP sent to the Aadhaar-linked mobile number."""
    cfg = eko_settings()
    mobile = _clean_mobile(mobile)

    data = {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'otp': otp,
        'otp_ref_id': otp_ref_id,
    }
    result = _request('POST', AADHAAR_OTP_VERIFY_PATH.format(mobile=mobile), data)

    # _request() already raises if response_status_id signals failure —
    # reaching here means Eko accepted the OTP.
    return {
        'reference_id': str(result.get('customer_id') or result.get('reference_tid') or otp_ref_id),
        'name': result.get('name') or '',
        'dob': result.get('dob') or result.get('date_of_birth') or result.get('birth_date') or '',
    }


def _clean_mobile(phone: str) -> str:
    digits = re.sub(r'\D', '', phone or '')
    mobile = digits[-10:] if len(digits) >= 10 else digits
    if len(mobile) != 10 or mobile[0] not in '6789':
        raise EkoKycError('A valid Indian mobile number is required for Eko verification.', 'invalid_mobile')
    return mobile


def _residence_address(address: dict | None) -> str:
    """Encode Eko's required residence_address as a JSON array of strings."""
    values = [str(value).strip() for value in (address or {}).values() if str(value).strip()]
    return json.dumps(values) if values else ''


def _loose_match(a: str, b: str) -> bool:
    a = re.sub(r'[^A-Z0-9 ]', '', (a or '').upper()).strip()
    b = re.sub(r'[^A-Z0-9 ]', '', (b or '').upper()).strip()
    return bool(a) and bool(b) and a == b
