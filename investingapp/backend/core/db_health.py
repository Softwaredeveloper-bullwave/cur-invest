"""Lightweight PostgreSQL connectivity probe for health checks and API guards."""

from __future__ import annotations

from django.conf import settings
from django.db import connection


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
        message = str(exc).split('\n')[0].strip()[:220]
        return {
            'engine': 'postgresql',
            'host': host or 'localhost',
            'name': name,
            'user': user,
            'reachable': False,
            'message': message,
        }
