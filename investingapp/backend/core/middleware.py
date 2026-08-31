import logging
import traceback

from django.db import DatabaseError, close_old_connections, connections

from .db_health import is_database_outage_text
from .error_reporting import record_error_event

logger = logging.getLogger('bullwave.requests')


def _is_health_path(path: str) -> bool:
    return path.split('?')[0].rstrip('/').endswith('/health')


class RequestLogMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        close_old_connections()
        if not _is_health_path(request.path):
            logger.info('%s %s', request.method, request.get_full_path())
        try:
            try:
                response = self.get_response(request)
            except DatabaseError as exc:
                # RDS outage: do not open another connection to persist the log.
                logger.error('%s %s failed: %s', request.method, request.path, exc)
                raise
            except Exception as exc:
                if not request.path.endswith('/client-errors/') and not is_database_outage_text(exc):
                    record_error_event(
                        source='backend',
                        severity='critical',
                        message=str(exc) or exc.__class__.__name__,
                        exception_type=exc.__class__.__name__,
                        logger_name='django.request',
                        location=request.path,
                        method=request.method,
                        status_code=500,
                        user=getattr(request, 'user', None),
                        context={'traceback': traceback.format_exc(limit=12)},
                    )
                raise
            if (
                response.status_code >= 500
                and response.status_code != 503
                and not request.path.endswith('/client-errors/')
            ):
                record_error_event(
                    source='backend',
                    message=f'HTTP {response.status_code} response',
                    exception_type='ServerResponseError',
                    logger_name='bullwave.requests',
                    location=request.path,
                    method=request.method,
                    status_code=response.status_code,
                    user=getattr(request, 'user', None),
                )
            return response
        finally:
            # Tiny RDS: never leave a backend checked out after the request.
            connections.close_all()
