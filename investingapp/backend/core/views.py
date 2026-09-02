from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from kyc.rate_limit import RateLimitExceeded, check_rate_limit

from .db_health import database_status
from .error_reporting import record_error_event
from .integrations.status import integration_status


class HealthView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        integrations = integration_status()
        db = database_status()
        integrations['database'] = db
        all_critical = integrations['market_data']['configured'] and db['reachable']
        status = 'ok' if all_critical else 'degraded'

        remote_addr = request.META.get('REMOTE_ADDR')
        forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
        is_internal = remote_addr in ('127.0.0.1', '::1') and not forwarded_for

        payload = {
            'status': status,
            'service': 'Capital BullWave API',
            'version': 'v1',
        }
        if is_internal:
            payload['integrations'] = integrations

        return Response(payload)

class ClientErrorReportView(APIView):
    """Rate-limited ingestion for already-sanitized mobile error reports."""

    permission_classes = [AllowAny]

    def post(self, request):
        content_length = int(request.META.get('CONTENT_LENGTH') or 0)
        if content_length > 16_000:
            return Response({'detail': 'Report is too large.'}, status=413)
        forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
        ip = forwarded.split(',')[0].strip() if forwarded else request.META.get('REMOTE_ADDR', 'unknown')
        try:
            check_rate_limit(f'client-error:{ip}', limit=30, window_seconds=60)
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)

        message = str(request.data.get('message') or '').strip()
        if not message:
            return Response({'detail': 'message is required.'}, status=400)
        context = request.data.get('context')
        if not isinstance(context, dict):
            context = {}
        stack_trace = str(request.data.get('stackTrace') or '')
        if stack_trace:
            context['stackTrace'] = stack_trace
        context['platform'] = request.data.get('platform')
        context['releaseMode'] = bool(request.data.get('releaseMode'))
        row = record_error_event(
            source='flutter',
            severity=str(request.data.get('severity') or 'error').lower(),
            message=message,
            exception_type=str(request.data.get('exceptionType') or ''),
            logger_name='bullwave.flutter',
            location=str(request.data.get('location') or ''),
            status_code=request.data.get('statusCode'),
            user=request.user,
            context=context,
        )
        if row is None:
            return Response({'detail': 'Report could not be stored.'}, status=503)
        return Response({'accepted': True, 'id': str(row.id)}, status=202)
# CI/CD pipeline test 4 - HOME env fix - safe to remove
