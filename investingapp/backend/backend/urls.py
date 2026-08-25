from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path

from core.views import ClientErrorReportView, HealthView


def _api_v1_payload(request):
    payload = {
        'name': 'Capital BullWave API',
        'version': 'v1',
        'status': 'running',
        'health': request.build_absolute_uri('/health/'),
        'endpoints': {
            'auth_send_otp': request.build_absolute_uri('/api/v1/auth/send-otp/'),
            'auth_verify_otp': request.build_absolute_uri('/api/v1/auth/verify-otp/'),
            'kyc_status': request.build_absolute_uri('/api/v1/kyc-status/'),
        },
    }
    if settings.DEBUG:
        payload['note'] = (
            'API is running. Use POST to auth endpoints from the app. '
            'In DEBUG mode, OTP may appear in the send-otp JSON as devOtp.'
        )
    return payload


def api_root(request):
    return JsonResponse(_api_v1_payload(request))


def api_v1_root(request):
    return JsonResponse(_api_v1_payload(request))


urlpatterns = [
    path('', api_root, name='api-root'),
    path('health/', HealthView.as_view(), name='health'),
    path('admin/', admin.site.urls),
    path('api/v1/', api_v1_root, name='api-v1-root'),
    path('api/v1', api_v1_root, name='api-v1-root-no-slash'),
    path('api/v1/admin-panel/', include('adminpanel.urls')),
    path('api/v1/client-errors/', ClientErrorReportView.as_view(), name='client-error-report'),
    path('api/v1/', include('accounts.urls')),
    path('api/v1/', include('kyc.urls')),
    path('api/v1/', include('payments.urls')),
    path('api/v1/', include('finance.urls')),
    path('api/v1/', include('stocks.urls')),
    path('api/v1/', include('crypto.urls')),
    path('api/v1/', include('engagement.urls')),
    path('api/v1/', include('education.urls')),
    path('api/v1/', include('ai.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
