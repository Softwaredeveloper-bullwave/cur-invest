"""PostgreSQL connectivity probe and JSON responses when the database is down."""

from __future__ import annotations

from pathlib import Path

from django.conf import settings
from django.core.cache import cache
from django.db import connection
from rest_framework.response import Response


def _json_text(value) -> str:
    if isinstance(value, Path):
        return str(value)
    return str(value or '')

DB_UNAVAILABLE_DETAIL = (
    'Login is temporarily unavailable. Please try again in a moment.'
)

DB_UNAVAILABLE_CODE = 'database_unavailable'

# Phrases from libpq / RDS when the instance is out of backends.
DB_OUTAGE_MARKERS = (
    'remaining connection slots',
    'rds_reserved',
    'too many connections',
    'connection slots are reserved',
    'could not connect to server',
    'connection to server at',
    'server closed the connection unexpectedly',
    'connection timed out',
    'connection refused',
    'database is unreachable',
)


def is_database_outage_text(*parts: object) -> bool:
    blob = ' '.join(str(part or '') for part in parts).lower()
    return any(marker in blob for marker in DB_OUTAGE_MARKERS)


def database_unavailable_response() -> Response:
    return Response(
        {'detail': DB_UNAVAILABLE_DETAIL, 'code': DB_UNAVAILABLE_CODE},
        status=503,
    )


def database_status(*, use_cache: bool = True) -> dict:
    """Return whether Django can connect to the configured database."""
    cache_key = 'db-health-status'
    if use_cache:
        cached = cache.get(cache_key)
        if isinstance(cached, dict):
            return cached

    db_settings = getattr(settings, 'DATABASES', {}).get('default', {})
    host = _json_text(db_settings.get('HOST', ''))
    name = _json_text(db_settings.get('NAME', ''))
    user = _json_text(db_settings.get('USER', ''))
    engine = 'sqlite' if 'sqlite' in _json_text(db_settings.get('ENGINE', '')).lower() else 'postgresql'
    try:
        connection.ensure_connection()
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        result = {
            'engine': engine,
            'host': host or 'localhost',
            'name': name,
            'user': user,
            'reachable': True,
            'message': 'ok',
        }
        cache.set(cache_key, result, 15)
        return result
    except Exception as exc:
        try:
            connection.close()
        except Exception:
            pass
        message = str(exc).split('\n')[0].strip()[:220]
        result = {
            'engine': engine,
            'host': host or 'localhost',
            'name': name,
            'user': user,
            'reachable': False,
            'message': message,
        }
        cache.set(cache_key, result, 15)
        return result
