"""Reusable Eko Platform Services authentication helpers.

Auth spec: https://developers.eko.in/docs/auth
  developer_key         — static key from Eko Connect
  secret-key            — base64(HMAC-SHA256(base64(access_key), secret-key-timestamp))
  secret-key-timestamp  — current UNIX time in milliseconds

All Eko integrations (bank, PAN, DigiLocker, UPI, …) should build headers via
this module — never duplicate HMAC logic elsewhere.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import time
from typing import Any

SENSITIVE_EKO_HEADER_KEYS = frozenset(
    {
        'developer_key',
        'secret-key',
        'secret_key',
        'access_key',
        'authorization',
    }
)

SENSITIVE_EKO_PAYLOAD_KEYS = frozenset(
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


def build_eko_auth_headers(
    *,
    developer_key: str,
    access_key: str,
    timestamp_ms: int | None = None,
    hmac_key_mode: str = 'b64_string',
) -> dict[str, str]:
    """Generate Eko `secret-key` + `secret-key-timestamp` for one request.

    Official Python sample (developers.eko.in): HMAC key is the base64 *string*
    of the access key. Some Eko JS samples decode that base64 first. We try
    ``b64_string`` first and ``raw`` on 401.
    """
    timestamp = str(timestamp_ms if timestamp_ms is not None else int(round(time.time() * 1000)))
    encoded_key = base64.b64encode(access_key.encode())
    hmac_key = access_key.encode() if hmac_key_mode == 'raw' else encoded_key
    signature = hmac.new(hmac_key, timestamp.encode(), hashlib.sha256).digest()
    secret_key = base64.b64encode(signature).decode()
    return {
        'developer_key': developer_key,
        'secret-key': secret_key,
        'secret-key-timestamp': timestamp,
        'accept': 'application/json',
    }


def build_eko_auth_headers_from_config(cfg, *, hmac_key_mode: str = 'b64_string') -> dict[str, str]:
    """Build auth headers from an ``EkoSettings`` dataclass."""
    return build_eko_auth_headers(
        developer_key=cfg.developer_key,
        access_key=cfg.access_key,
        hmac_key_mode=hmac_key_mode,
    )


def redact_eko_headers(headers: dict[str, Any] | None) -> dict[str, Any]:
    if not headers:
        return {}
    return {
        key: ('***' if str(key).lower() in SENSITIVE_EKO_HEADER_KEYS else value)
        for key, value in headers.items()
    }


def sanitize_eko_payload(payload: Any, *, mask_pan=None, mask_account=None) -> Any:
    """Redact secrets and PII before logging."""

    def scrub(value: Any, key: str = '') -> Any:
        if isinstance(value, dict):
            cleaned = {}
            for child_key, child_value in value.items():
                lowered = str(child_key).lower()
                if lowered in SENSITIVE_EKO_PAYLOAD_KEYS:
                    cleaned[child_key] = '***'
                    continue
                if mask_pan and lowered in {'pan_number', 'pannumber'}:
                    cleaned[child_key] = mask_pan(str(child_value))
                    continue
                if mask_account and lowered in {'bank_account', 'account', 'account_number'}:
                    cleaned[child_key] = mask_account(str(child_value))
                    continue
                if 'pan' in lowered and 'number' in lowered and mask_pan:
                    cleaned[child_key] = mask_pan(str(child_value))
                    continue
                cleaned[child_key] = scrub(child_value, lowered)
            return cleaned
        if isinstance(value, list):
            return [scrub(item) for item in value]
        return value

    if isinstance(payload, dict):
        return scrub(payload)
    return payload
