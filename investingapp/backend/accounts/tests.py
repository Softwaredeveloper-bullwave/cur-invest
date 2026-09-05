from unittest.mock import patch

from django.db import DatabaseError
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIRequestFactory

from .views import SendOTPView

_FLUTTER_WEB_CORS = dict(
    DEBUG=False,
    CORS_ALLOW_ALL_ORIGINS=False,
    CORS_ALLOWED_ORIGINS=['https://app.capitalbullwave.com'],
    CORS_ALLOWED_ORIGIN_REGEXES=[
        r'^https?://localhost:\d+$',
        r'^https?://127\.0\.0\.1:\d+$',
        r'^https?://\[::1\]:\d+$',
    ],
)


class DisabledSmsOtpTests(SimpleTestCase):
    @override_settings(SMS_OTP_ENABLED=False, DEBUG=True)
    @patch.object(SendOTPView, '_registration_hint', return_value={'isRegistered': False})
    @patch.object(SendOTPView, '_issue_local_otp', return_value='123456')
    @patch('accounts.views.send_otp_sms')
    def test_debug_login_generates_local_otp_without_sms(
        self,
        send_sms_mock,
        issue_otp_mock,
        _hint_mock,
    ):
        request = APIRequestFactory().post(
            '/api/v1/auth/send-otp/',
            {'phone': '8700799173'},
            format='json',
        )

        response = SendOTPView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['otpMode'], 'console')
        self.assertEqual(response.data['devOtp'], '123456')
        issue_otp_mock.assert_called_once_with('8700799173')
        send_sms_mock.assert_not_called()

    @patch.object(SendOTPView, '_registration_hint', side_effect=DatabaseError('too many connections'))
    def test_send_otp_returns_json_when_database_is_down(self, _hint_mock):
        request = APIRequestFactory().post(
            '/api/v1/auth/send-otp/',
            {'phone': '8700799173'},
            format='json',
        )

        response = SendOTPView.as_view()(request)

        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.data['code'], 'database_unavailable')
        self.assertIn('try again', response.data['detail'].lower())


@override_settings(**_FLUTTER_WEB_CORS)
class FlutterWebCorsTests(SimpleTestCase):
    def test_localhost_preflight_allows_flutter_chrome_origin(self):
        response = self.client.options(
            '/api/v1/auth/send-otp/',
            HTTP_ORIGIN='http://localhost:55221',
            HTTP_ACCESS_CONTROL_REQUEST_METHOD='POST',
            HTTP_ACCESS_CONTROL_REQUEST_HEADERS='content-type',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response['Access-Control-Allow-Origin'], 'http://localhost:55221')

    def test_unknown_origin_is_not_reflected(self):
        response = self.client.options(
            '/api/v1/auth/send-otp/',
            HTTP_ORIGIN='https://evil.example',
            HTTP_ACCESS_CONTROL_REQUEST_METHOD='POST',
            HTTP_ACCESS_CONTROL_REQUEST_HEADERS='content-type',
        )
        self.assertNotEqual(response.get('Access-Control-Allow-Origin'), 'https://evil.example')

