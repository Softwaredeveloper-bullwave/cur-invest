"""Simple cache-based rate limiting for verification endpoints."""

import time
from typing import Optional

from django.conf import settings
from django.core.cache import cache


class RateLimitExceeded(Exception):
    def __init__(self, message: str, *, retry_after: Optional[int] = None):
        super().__init__(message)
        self.retry_after = retry_after


def _effective_limits(limit: int, window_seconds: int) -> tuple[int, int]:
    """Looser caps while iterating on KYC locally — still enforced in production."""
    relax = getattr(settings, 'KYC_RELAX_RATE_LIMITS', settings.DEBUG)
    if relax:
        return max(limit, 25), min(window_seconds, 120)
    return limit, window_seconds


def clear_rate_limit(key: str) -> None:
    cache.delete(f'ratelimit:{key}')


def rate_limit_response(exc: RateLimitExceeded):
    from rest_framework.response import Response

    payload = {'detail': str(exc)}
    if exc.retry_after is not None:
        payload['retry_after_seconds'] = exc.retry_after
    return Response(payload, status=429)


def check_rate_limit(key: str, limit: int = 10, window_seconds: int = 60) -> None:
    limit, window_seconds = _effective_limits(limit, window_seconds)
    cache_key = f'ratelimit:{key}'
    now = time.time()
    bucket = cache.get(cache_key)

    if isinstance(bucket, dict):
        count = int(bucket.get('count') or 0)
        expires_at = float(bucket.get('expires_at') or 0)
        if now >= expires_at:
            count = 0
            expires_at = now + window_seconds
    else:
        count = int(bucket or 0)
        expires_at = now + window_seconds

    if count >= limit:
        retry_after = max(1, int(expires_at - now))
        raise RateLimitExceeded(
            f'Too many attempts. Try again in {retry_after} seconds.',
            retry_after=retry_after,
        )

    cache.set(
        cache_key,
        {'count': count + 1, 'expires_at': expires_at},
        window_seconds,
    )
