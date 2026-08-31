from unittest.mock import patch

from django.db import DatabaseError
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIRequestFactory

from .views import SendOTPView


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

