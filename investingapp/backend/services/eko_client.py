"""Shared HTTP transport for Eko Platform Services."""

from __future__ import annotations

import json
import logging

import httpx

from services.eko_auth import build_eko_auth_headers_from_config, redact_eko_headers, sanitize_eko_payload
from services.providers.eko_config import eko_settings

logger = logging.getLogger('bullwave.kyc')


class EkoTransportError(Exception):
    def __init__(self, message: str, code: str = '', *, eko_meta: dict | None = None):
        super().__init__(message)
        self.code = code
        self.eko_meta = eko_meta or {}


def _http_timeout(cfg) -> httpx.Timeout:
    read_seconds = max(30.0, float(cfg.http_timeout_seconds))
    return httpx.Timeout(connect=15.0, read=read_seconds, write=30.0, pool=15.0)


def eko_post_json(
    path: str,
    payload: dict,
    *,
    base_url: str | None = None,
    mask_account=None,
) -> tuple[dict, dict]:
    """POST JSON to Eko. Returns ``(envelope, inner_data)``."""
    cfg = eko_settings()
    if not cfg.is_configured:
        raise EkoTransportError('Eko API credentials are not configured.', 'not_configured')

    url = f'{(base_url or cfg.base_url).rstrip("/")}{path}'
    headers = build_eko_auth_headers_from_config(cfg)
    headers['content-type'] = 'application/json'

    logger.info('Eko POST %s', path)
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            'Eko request headers (redacted): %s body: %s',
            redact_eko_headers(headers),
            json.dumps(
                sanitize_eko_payload(payload, mask_account=mask_account),
                default=str,
                ensure_ascii=False,
            ),
        )

    response = _execute_http(
        method='POST',
        url=url,
        headers=headers,
        cfg=cfg,
        json_body=payload,
    )

    envelope: dict = {}
    try:
        envelope = response.json()
    except Exception:
        envelope = {}

    inner = _unwrap_data(envelope)
    if logger.isEnabledFor(logging.DEBUG):
        logger.debug(
            'Eko response %s: %s',
            path,
            json.dumps(sanitize_eko_payload(envelope, mask_account=mask_account), default=str),
        )

    logger.info(
        'Eko POST %s -> HTTP %s response_status_id=%s status=%s',
        path,
        response.status_code,
        envelope.get('response_status_id'),
        envelope.get('status'),
    )

    if response.status_code == 401:
        raise EkoTransportError(
            'Invalid Eko developer key or secret key.',
            'auth_failed',
            eko_meta=_meta_from_envelope(envelope),
        )

    if response.is_error:
        message = _safe_error_message(envelope, response)
        raise EkoTransportError(
            message,
            str(envelope.get('response_status_id') or response.status_code),
            eko_meta=_meta_from_envelope(envelope),
        )

    return envelope, inner


def _unwrap_data(envelope: dict) -> dict:
    data = envelope.get('data')
    if isinstance(data, dict):
        return data
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                return item
    return envelope if isinstance(envelope, dict) else {}


def _meta_from_envelope(envelope: dict) -> dict:
    inner = _unwrap_data(envelope)
    reference_id = (
        inner.get('reference_id')
        or inner.get('transaction_id')
        or inner.get('client_ref_id')
        or envelope.get('reference_id')
        or ''
    )
    return {
        'message': (envelope.get('message') or '').strip(),
        'responseStatusId': envelope.get('response_status_id'),
        'responseTypeId': envelope.get('response_type_id'),
        'status': envelope.get('status'),
        'referenceId': str(reference_id) if reference_id not in (None, '') else '',
    }


def _safe_error_message(envelope: dict, response: httpx.Response) -> str:
    message = envelope.get('message') if isinstance(envelope, dict) else ''
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


def _execute_http(
    *,
    method: str,
    url: str,
    headers: dict,
    cfg,
    json_body: dict | None = None,
) -> httpx.Response:
    timeout = _http_timeout(cfg)
    last_timeout: httpx.HTTPError | None = None
    for attempt in range(2):
        try:
            with httpx.Client(timeout=timeout) as client:
                return client.request(method, url, json=json_body, headers=headers)
        except (httpx.ReadTimeout, httpx.ConnectTimeout, httpx.WriteTimeout) as exc:
            last_timeout = exc
            if attempt == 0:
                logger.warning('Eko %s timed out — retrying once', url)
                continue
            raise EkoTransportError(
                'Eko is taking too long to respond. Please try again in a moment.',
                'timeout',
            ) from exc
        except httpx.HTTPError as exc:
            raise EkoTransportError(f'Eko connection failed: {exc}', 'network_error') from exc
    raise EkoTransportError(
        'Eko is taking too long to respond. Please try again in a moment.',
        'timeout',
    ) from last_timeout
