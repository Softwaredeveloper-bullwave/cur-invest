"""DRF exception mapping so APIs return JSON instead of HTML 500 pages."""

from __future__ import annotations

import logging

from django.conf import settings
from django.db import DatabaseError
from rest_framework.response import Response
from rest_framework.views import exception_handler

from .db_health import database_unavailable_response

logger = logging.getLogger('bullwave.api')


def api_exception_handler(exc, context):
    if isinstance(exc, DatabaseError):
        return database_unavailable_response()
    response = exception_handler(exc, context)
    if response is not None:
        return response
    logger.exception('Unhandled API error')
    detail = 'Server error. Please try again in a moment.'
    if getattr(settings, 'DEBUG', False):
        detail = str(exc) or detail
    return Response({'detail': detail, 'code': 'server_error'}, status=500)
