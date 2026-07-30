from unittest.mock import patch

from django.test import SimpleTestCase, override_settings
from rest_framework.test import APIRequestFactory

from .views import SendOTPView


class DisabledSmsOtpTests(SimpleTestCase):
    @override_settings(SMS_OTP_ENABLED=False, DEBUG=True)
    @patch.object(SendOTPView, '_issue_local_otp', return_value='123456')
    @patch('accounts.views.send_otp_sms')
    def test_debug_login_generates_local_otp_without_sms(
        self,
        send_sms_mock,
        issue_otp_mock,
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
