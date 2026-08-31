"""Logging handler that persists only sanitized ERROR/CRITICAL records."""

import logging

from .db_health import is_database_outage_text
from .error_reporting import record_error_event


class DatabaseErrorHandler(logging.Handler):
    def emit(self, record):
        try:
            formatted = ''
            try:
                formatted = self.format(record)
            except Exception:
                formatted = record.getMessage()
            if is_database_outage_text(record.getMessage(), formatted):
                return
            exception_type = ''
            context = {}
            if record.exc_info:
                exception_type = record.exc_info[0].__name__
                context['traceback'] = formatted or self.format(record)
            request = getattr(record, 'request', None)
            record_error_event(
                source='backend',
                severity='critical' if record.levelno >= logging.CRITICAL else 'error',
                message=record.getMessage(),
                exception_type=exception_type,
                logger_name=record.name,
                location=getattr(request, 'path', '') or getattr(record, 'pathname', ''),
                method=getattr(request, 'method', ''),
                status_code=getattr(record, 'status_code', None),
                user=getattr(request, 'user', None),
                context=context,
            )
        except Exception:
            self.handleError(record)
