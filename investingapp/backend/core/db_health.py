"""PostgreSQL connectivity probe and JSON responses when the database is down."""

from __future__ import annotations

from django.conf import settings
from django.db import connection
from rest_framework.response import Response

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


def database_status() -> dict:
    """Return whether Django can connect to the configured database."""
    host = getattr(settings, 'DATABASES', {}).get('default', {}).get('HOST', '')
    name = getattr(settings, 'DATABASES', {}).get('default', {}).get('NAME', '')
    user = getattr(settings, 'DATABASES', {}).get('default', {}).get('USER', '')
    try:
        connection.ensure_connection()
        with connection.cursor() as cursor:
            cursor.execute('SELECT 1')
        return {
            'engine': 'postgresql',
            'host': host or 'localhost',
            'name': name,
            'user': user,
            'reachable': True,
            'message': 'ok',
        }
    except Exception as exc:
        try:
            connection.close()
        except Exception:
            pass
        message = str(exc).split('\n')[0].strip()[:220]
        return {
            'engine': 'postgresql',
            'host': host or 'localhost',
            'name': name,
            'user': user,
            'reachable': False,
            'message': message,
        }
