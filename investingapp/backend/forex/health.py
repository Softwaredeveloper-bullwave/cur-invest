"""Provider health monitoring — never stores API secrets; never fails the request."""

from __future__ import annotations

import logging

from django.utils import timezone

from .models import ForexApiRequestLog, ForexProviderHealth

logger = logging.getLogger('bullwave.forex')


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
    try:
        health, _ = ForexProviderHealth.objects.get_or_create(
            service=service,
            defaults={'provider_name': provider_name},
        )
        if provider_name:
            health.provider_name = provider_name
        if success:
            health.success_count = (health.success_count or 0) + 1
            health.last_success_at = timezone.now()
            if response_ms is not None:
                health.avg_response_ms = (
                    int((health.avg_response_ms + response_ms) / 2)
                    if health.avg_response_ms
                    else response_ms
                )
            health.status = ForexProviderHealth.Status.HEALTHY
        else:
            health.error_count = (health.error_count or 0) + 1
            health.last_error_at = timezone.now()
            health.last_error_message = (error_message or error_type or 'error')[:500]
            health.status = (
                ForexProviderHealth.Status.DEGRADED
                if status_code == 429
                else ForexProviderHealth.Status.DOWN
            )
            if status_code == 429:
                health.rate_limit_hits = (health.rate_limit_hits or 0) + 1
        health.save()
        ForexApiRequestLog.objects.create(
            service=service,
            endpoint=endpoint[:200],
            success=success,
            status_code=status_code,
            response_ms=response_ms,
            error_type=(error_type or '')[:64],
        )
    except Exception:
        logger.debug('Forex health log skipped', exc_info=True)


def health_summary() -> dict:
    try:
        out = {}
        for svc in ('market_data', 'news'):
            h = ForexProviderHealth.objects.filter(service=svc).first()
            if not h:
                out[svc] = {'status': 'UNKNOWN', 'provider': ''}
                continue
            out[svc] = {
                'status': h.status,
                'provider': h.provider_name,
                'last_success_at': h.last_success_at.isoformat() if h.last_success_at else None,
                'avg_response_ms': h.avg_response_ms,
            }
        return out
    except Exception:
        return {'market_data': {'status': 'UNKNOWN', 'provider': ''}}
