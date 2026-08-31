"""DRF exception mapping so APIs return JSON instead of HTML 500 pages."""

from __future__ import annotations

from django.db import DatabaseError
from rest_framework.views import exception_handler

from .db_health import database_unavailable_response


def api_exception_handler(exc, context):
    if isinstance(exc, DatabaseError):
        return database_unavailable_response()
    return exception_handler(exc, context)
