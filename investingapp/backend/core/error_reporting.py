"""Sanitized application-error persistence shared by middleware and APIs."""

import hashlib
import json
import re
from datetime import timedelta
from typing import Any, Optional

from django.core.cache import cache
from django.db import transaction
from django.db.models import F
from django.db.utils import InterfaceError, OperationalError
from django.utils import timezone

from .db_health import is_database_outage_text

_ERROR_REPORTING_SKIP_KEY = 'error-reporting-db-skip'


SENSITIVE_KEYS = {
    'authorization',
    'password',
    'passcode',
    'token',
    'access_token',
    'refresh_token',
    'secret',
    'secret_key',
    'api_key',
    'otp',
    'pin',
    'pan',
    'pan_number',
    'aadhaar',
    'aadhaar_number',
    'account_number',
    'bank_account_number',
    'card_number',
    'cvv',
}
_EMAIL_RE = re.compile(r'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b')
_PHONE_RE = re.compile(r'(?<!\d)(?:\+?91[- ]?)?[6-9]\d{9}(?!\d)')
_PAN_RE = re.compile(r'(?i)\b[A-Z]{5}\d{4}[A-Z]\b')
_AADHAAR_RE = re.compile(r'(?<!\d)\d{4}[ -]?\d{4}[ -]?\d{4}(?!\d)')
_ACCOUNT_RE = re.compile(r'(?<!\d)\d{9,18}(?!\d)')
_UUID_RE = re.compile(r'\b[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\b')


def sanitize_text(value: Any, limit: int = 500) -> str:
    text = str(value or '')
    text = _EMAIL_RE.sub('[email]', text)
    text = _PHONE_RE.sub('[phone]', text)
    text = _PAN_RE.sub('[pan]', text)
    text = _AADHAAR_RE.sub('[aadhaar]', text)
    text = _ACCOUNT_RE.sub('[number]', text)
    return text[:limit]


def sanitize_context(value: Any, *, depth: int = 0) -> Any:
    if depth > 4:
        return '[truncated]'
    if isinstance(value, dict):
        cleaned = {}
        for key, item in list(value.items())[:50]:
            normalized = str(key).lower().replace('-', '_')
            cleaned[str(key)[:80]] = (
                '[redacted]'
                if normalized in SENSITIVE_KEYS or any(part in normalized for part in ('password', 'token', 'secret'))
                else sanitize_context(item, depth=depth + 1)
            )
        return cleaned
    if isinstance(value, (list, tuple)):
        return [sanitize_context(item, depth=depth + 1) for item in list(value)[:30]]
    if value is None or isinstance(value, (bool, int, float)):
        return value
    return sanitize_text(value, 1000)


def safe_context(value: Any) -> dict:
    cleaned = sanitize_context(value if isinstance(value, dict) else {'detail': value})
    encoded = json.dumps(cleaned, default=str)
    if len(encoded) <= 8000:
        return cleaned
    return {'detail': sanitize_text(encoded, 7800), 'truncated': True}


def build_fingerprint(*, source: str, exception_type: str, message: str, location: str) -> str:
    normalized_message = _UUID_RE.sub('[uuid]', sanitize_text(message, 500))
    normalized_message = re.sub(r'\d+', '#', normalized_message.lower())
    raw = '|'.join((source, exception_type.lower(), location.split('?')[0], normalized_message))
    return hashlib.sha256(raw.encode('utf-8')).hexdigest()


def record_error_event(
    *,
    source: str,
    message: Any,
    severity: str = 'error',
    exception_type: str = '',
    logger_name: str = '',
    location: str = '',
    method: str = '',
    status_code: Optional[int] = None,
    user=None,
    context: Optional[dict] = None,
):
    """Insert or increment an error without ever raising into application code."""
    from adminpanel.models import ApplicationErrorEvent

    if cache.get(_ERROR_REPORTING_SKIP_KEY):
        return None
    if is_database_outage_text(message, exception_type, context):
        return None

    clean_message = sanitize_text(message)
    clean_location = sanitize_text(str(location).split('?')[0], 300)
    clean_exception = sanitize_text(exception_type, 160)
    fingerprint = build_fingerprint(
        source=source,
        exception_type=clean_exception,
        message=clean_message,
        location=clean_location,
    )
    defaults = {
        'severity': severity if severity in ApplicationErrorEvent.Severity.values else 'error',
        'logger_name': sanitize_text(logger_name, 160),
        'message': clean_message or 'Unknown application error',
        'exception_type': clean_exception,
        'location': clean_location,
        'method': sanitize_text(method, 12).upper(),
        'status_code': status_code if isinstance(status_code, int) and 100 <= status_code <= 599 else None,
        'user': user if getattr(user, 'is_authenticated', False) else None,
        'context': safe_context(context or {}),
        'last_seen_at': timezone.now(),
    }
    try:
        if cache.add('application-error-retention-cleanup', True, timeout=86_400):
            ApplicationErrorEvent.objects.filter(
                last_seen_at__lt=timezone.now() - timedelta(days=90)
            ).delete()
        with transaction.atomic():
            row, created = ApplicationErrorEvent.objects.get_or_create(
                source=source,
                fingerprint=fingerprint,
                defaults=defaults,
            )
            if not created:
                ApplicationErrorEvent.objects.filter(pk=row.pk).update(
                    occurrence_count=F('occurrence_count') + 1,
                    last_seen_at=timezone.now(),
                    severity=defaults['severity'],
                    message=defaults['message'],
                    context=defaults['context'],
                    status=ApplicationErrorEvent.Status.OPEN,
                    resolved_by=None,
                    resolved_at=None,
                )
                row.refresh_from_db()
            return row
    except (OperationalError, InterfaceError):
        # Writing the error log must not consume the last RDS slots.
        cache.set(_ERROR_REPORTING_SKIP_KEY, True, 90)
        return None
    except Exception:
        # Error reporting must never break the request it observes.
        return None
