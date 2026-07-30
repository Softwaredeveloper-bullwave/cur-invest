import logging
import traceback

from .error_reporting import record_error_event

logger = logging.getLogger('bullwave.requests')


class RequestLogMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        logger.info('%s %s', request.method, request.get_full_path())
        try:
            response = self.get_response(request)
        except Exception as exc:
            if not request.path.endswith('/client-errors/'):
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
        if response.status_code >= 500 and not request.path.endswith('/client-errors/'):
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
