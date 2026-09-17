"""Guarantee CORS on API responses so Flutter Chrome can call the AWS Elastic IP."""

from __future__ import annotations

from django.http import HttpResponse

_ALLOW_METHODS = 'DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT'
_ALLOW_HEADERS = (
    'accept, authorization, content-type, origin, x-csrftoken, x-requested-with'
)


def _origin_allowed(origin: str) -> bool:
    value = (origin or '').strip()
    if not value:
        return False
    lower = value.lower()
    if lower.startswith(('http://localhost:', 'http://127.0.0.1:', 'http://[::1]:')):
        return True
    if lower.startswith(('https://localhost:', 'https://127.0.0.1:', 'https://[::1]:')):
        return True
    if lower in ('http://localhost', 'http://127.0.0.1', 'https://localhost', 'https://127.0.0.1'):
        return True
    host = lower.split('://', 1)[-1].split('/', 1)[0].split(':', 1)[0]
    return host == '43.204.159.255' or host.endswith('capitalbullwave.com') or host.endswith('bullwave.in')


class EnsureApiCorsMiddleware:
    """Add CORS headers when django-cors-headers leaves them off (production EIP)."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        origin = (request.META.get('HTTP_ORIGIN') or '').strip()
        if request.method == 'OPTIONS' and _origin_allowed(origin):
            response = HttpResponse(status=200)
            self._apply(request, response)
            return response
        response = self.get_response(request)
        self._apply(request, response)
        return response

    def _apply(self, request, response) -> None:
        origin = (request.META.get('HTTP_ORIGIN') or '').strip()
        if not _origin_allowed(origin):
            return
        response['Access-Control-Allow-Origin'] = origin
        response['Access-Control-Allow-Methods'] = _ALLOW_METHODS
        requested = (request.META.get('HTTP_ACCESS_CONTROL_REQUEST_HEADERS') or '').strip()
        response['Access-Control-Allow-Headers'] = requested or _ALLOW_HEADERS
        response['Access-Control-Max-Age'] = '86400'
        response['Access-Control-Allow-Credentials'] = 'false'
        vary = response.get('Vary', '')
        if 'origin' not in vary.lower():
            response['Vary'] = f'{vary}, Origin'.strip(', ')
