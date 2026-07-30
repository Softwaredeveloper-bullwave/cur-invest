from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIRequestFactory, force_authenticate

from .email_otp_service import EmailOtpError, send_email_otp, verify_email_otp
from .views import SendEmailOTPView, VerifyEmailOTPView

User = get_user_model()


class EmailOtpServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9876543210', password='test-pass')

    @override_settings(DEBUG=True, OTP_EXPIRY_MINUTES=10)
    @patch('accounts.email_otp_service.email_delivery_chain', return_value=[])
    def test_send_email_otp_console_mode_in_debug(self, _chain_mock):
        payload = send_email_otp(user=self.user, email='test@example.com')

        self.assertEqual(payload['otpMode'], 'console')
        self.assertTrue(payload['devOtp'])
        self.user.refresh_from_db()
        self.assertEqual(self.user.email, 'test@example.com')
        self.assertFalse(self.user.email_verified)

    @override_settings(DEBUG=True, OTP_EXPIRY_MINUTES=10)
    @patch('accounts.email_otp_service.email_delivery_chain', return_value=[])
    def test_verify_email_otp_marks_user_verified(self, _chain_mock):
        payload = send_email_otp(user=self.user, email='verify@example.com')
        user = verify_email_otp(
            user=self.user,
            email='verify@example.com',
            otp=payload['devOtp'],
        )

        self.assertTrue(user.email_verified)
        self.assertEqual(user.email, 'verify@example.com')

    @override_settings(DEBUG=True)
    @patch('accounts.email_otp_service.email_delivery_chain', return_value=[])
    def test_verify_email_otp_rejects_wrong_code(self, _chain_mock):
        send_email_otp(user=self.user, email='wrong@example.com')

        with self.assertRaises(EmailOtpError):
            verify_email_otp(user=self.user, email='wrong@example.com', otp='000000')


class EmailOtpViewTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9123456789', password='test-pass')
        self.factory = APIRequestFactory()

    @override_settings(DEBUG=True, OTP_EXPIRY_MINUTES=10)
    @patch('accounts.email_otp_service.email_delivery_chain', return_value=[])
    def test_send_email_otp_view(self, _chain_mock):
        request = self.factory.post(
            '/api/v1/auth/send-email-otp/',
            {'email': 'api@example.com'},
            format='json',
        )
        force_authenticate(request, user=self.user)

        response = SendEmailOTPView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['otpMode'], 'console')
        self.assertFalse(response.data['user']['emailVerified'])

    @override_settings(DEBUG=True, OTP_EXPIRY_MINUTES=10)
    @patch('accounts.email_otp_service.email_delivery_chain', return_value=[])
    def test_verify_email_otp_view(self, _chain_mock):
        send_payload = send_email_otp(user=self.user, email='api-verify@example.com')

        request = self.factory.post(
            '/api/v1/auth/verify-email-otp/',
            {'email': 'api-verify@example.com', 'otp': send_payload['devOtp']},
            format='json',
        )
        force_authenticate(request, user=self.user)

        response = VerifyEmailOTPView.as_view()(request)

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['user']['emailVerified'])
