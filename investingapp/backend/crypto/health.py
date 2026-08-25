"""Provider health monitoring — never stores API secrets."""

from __future__ import annotations

from django.utils import timezone

from .models import CryptoApiRequestLog, CryptoProviderHealth


def record_provider_call(
    *,
    service: str,
    endpoint: str,
    success: bool,
    response_ms: int | None = None,
    status_code: int | None = None,
    error_type: str = '',
    error_message: str = '',
    provider_name: str = '',
) -> None:
    health, _ = CryptoProviderHealth.objects.get_or_create(
        service=service,
        defaults={'provider_name': provider_name},
    )
    if provider_name:
        health.provider_name = provider_name

    if success:
        health.success_count = (health.success_count or 0) + 1
        health.last_success_at = timezone.now()
        if response_ms is not None:
            if health.avg_response_ms:
                health.avg_response_ms = int((health.avg_response_ms + response_ms) / 2)
            else:
                health.avg_response_ms = response_ms
            health.data_freshness_seconds = 0
        # Status thresholds
        if health.error_count and health.success_count:
            ratio = health.error_count / max(health.success_count + health.error_count, 1)
            health.status = (
                CryptoProviderHealth.Status.DEGRADED
                if ratio > 0.2
                else CryptoProviderHealth.Status.HEALTHY
            )
        else:
            health.status = CryptoProviderHealth.Status.HEALTHY
    else:
        health.error_count = (health.error_count or 0) + 1
        health.last_error_at = timezone.now()
        health.last_error_message = (error_message or error_type or 'error')[:500]
        if status_code == 429:
            health.rate_limit_hits = (health.rate_limit_hits or 0) + 1
            health.status = CryptoProviderHealth.Status.DEGRADED
        else:
            health.status = CryptoProviderHealth.Status.DOWN

    health.save()
    CryptoApiRequestLog.objects.create(
        service=service,
        endpoint=endpoint[:200],
        success=success,
        status_code=status_code,
        response_ms=response_ms,
        error_type=(error_type or '')[:64],
    )


def health_summary() -> dict:
    services = ('market_data', 'news', 'ai')
    out = {}
    for svc in services:
        try:
            h = CryptoProviderHealth.objects.filter(service=svc).first()
        except Exception:
            h = None
        if not h:
            out[svc] = {
                'status': 'UNKNOWN',
                'provider': '',
                'last_success_at': None,
                'avg_response_ms': None,
            }
            continue
        out[svc] = {
            'status': h.status,
            'provider': h.provider_name,
            'last_success_at': h.last_success_at.isoformat() if h.last_success_at else None,
            'last_error_at': h.last_error_at.isoformat() if h.last_error_at else None,
            'avg_response_ms': h.avg_response_ms,
            'rate_limit_hits': h.rate_limit_hits,
            'error_count': h.error_count,
            'success_count': h.success_count,
            'data_freshness_seconds': h.data_freshness_seconds,
        }
    return out
