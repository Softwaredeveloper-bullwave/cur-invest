from types import SimpleNamespace
from unittest.mock import MagicMock, patch

from django.test import SimpleTestCase, override_settings

from kyc.providers import (
    aadhaar_provider,
    bank_provider,
    legacy_kyc_provider,
    pan_provider,
    step_providers_payload,
    upi_provider,
)
from services.providers.cashfree_secure_id import CashfreeSecureIdError, verify_upi_vpa
from services.providers.eko_kyc import EkoKycError


class StepProviderSettingsTests(SimpleTestCase):
    @override_settings(KYC_PROVIDER='eko', KYC_PAN_PROVIDER='', KYC_BANK_PROVIDER='', KYC_UPI_PROVIDER='', KYC_AADHAAR_PROVIDER='')
    def test_falls_back_to_legacy_kyc_provider(self):
        self.assertEqual(legacy_kyc_provider(), 'eko')
        self.assertEqual(pan_provider(), 'eko')
        self.assertEqual(bank_provider(), 'eko')

    @override_settings(
        KYC_PROVIDER='eko',
        KYC_PAN_PROVIDER='eko',
        KYC_BANK_PROVIDER='cashfree',
        KYC_UPI_PROVIDER='cashfree',
        KYC_AADHAAR_PROVIDER='eko',
    )
    def test_per_step_overrides(self):
        self.assertEqual(pan_provider(), 'eko')
        self.assertEqual(bank_provider(), 'cashfree')
        self.assertEqual(upi_provider(), 'cashfree')
        self.assertEqual(aadhaar_provider(), 'eko')
        payload = step_providers_payload()
        self.assertEqual(payload['bank'], 'cashfree')
        self.assertEqual(payload['legacy'], 'eko')


class CashfreeSecureIdUpiTests(SimpleTestCase):
    @patch('services.providers.cashfree_secure_id._post')
    def test_verify_upi_vpa_maps_name_at_bank(self, post_mock):
        post_mock.return_value = {
            'reference_id': 999,
            'status': 'VALID',
            'vpa': 'success@upi',
            'name_at_bank': 'JOHN DOE',
        }
        result = verify_upi_vpa(customer_vpa='success@upi', name='John Doe', verification_id='test_upi_1')
        self.assertEqual(result['recipient_name'], 'JOHN DOE')
        self.assertEqual(result['verification_method'], 'upi_penny_drop')
        post_mock.assert_called_once()
        payload = post_mock.call_args.args[1]
        self.assertEqual(payload['vpa'], 'success@upi')
        self.assertTrue(payload['user_consent']['obtained'])

    @patch('services.providers.cashfree_secure_id._post')
    def test_invalid_upi_raises(self, post_mock):
        post_mock.return_value = {'status': 'INVALID', 'vpa': 'bad@upi'}
        with self.assertRaises(CashfreeSecureIdError) as ctx:
            verify_upi_vpa(customer_vpa='bad@upi', name='John Doe', verification_id='test_upi_2')
        self.assertEqual(ctx.exception.code, 'upi_invalid')


class EkoUpiRoutingTests(SimpleTestCase):
    @override_settings(KYC_UPI_PROVIDER='eko')
    @patch('kyc.service.eko_verify_upi_vpa')
    def test_verify_upi_uses_eko_when_configured(self, eko_mock):
        from kyc.service import _verify_upi

        eko_mock.return_value = {
            'vpa': '8285623224@paytm',
            'valid': True,
            'recipient_name': 'GOPAL KUMAR',
            'mobile_number': '8285623224',
            'reference_id': 'eko-upi-1',
        }
        result = _verify_upi(
            customer_vpa='8285623224@paytm',
            name='GOPAL KUMAR',
            recipient_mobile='8285623224',
        )
        self.assertEqual(result['recipient_name'], 'GOPAL KUMAR')
        eko_mock.assert_called_once_with(
            customer_vpa='8285623224@paytm',
            recipient_mobile='8285623224',
            name='GOPAL KUMAR',
            latlong='',
            customer_id='',
            dob='',
            address=None,
        )


class VerifyBankStepRoutingTests(SimpleTestCase):
    @override_settings(
        KYC_PROVIDER='eko',
        KYC_BANK_PROVIDER='cashfree',
        KYC_PAN_PROVIDER='eko',
    )
    @patch('kyc.service.cashfree_verify_bank_account')
    def test_verify_bank_uses_cashfree_when_configured(self, cashfree_mock):
        from kyc.service import _verify_bank

        cashfree_mock.return_value = {
            'reference_id': 'cf-1',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'PNB',
            'branch': 'Delhi',
            'verification_method': 'penny_drop',
        }
        result = _verify_bank(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
            name='GOPAL KUMAR',
            phone='9871013472',
        )
        self.assertEqual(result['reference_id'], 'cf-1')
        cashfree_mock.assert_called_once()

    @override_settings(KYC_PROVIDER='eko', KYC_BANK_PROVIDER='eko')
    @patch('kyc.service.eko_verify_bank_account')
    def test_verify_bank_uses_eko_when_configured(self, eko_mock):
        from kyc.service import _verify_bank

        eko_mock.return_value = {'reference_id': 'eko-1', 'name_at_bank': 'GOPAL KUMAR', 'verification_method': 'penny_drop'}
        _verify_bank(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
            name='GOPAL KUMAR',
            phone='9871013472',
        )
        eko_mock.assert_called_once()


class CashfreeErrorMappingTests(SimpleTestCase):
    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_rate_limit_maps_to_code(self, client_mock, settings_mock):
        settings_mock.return_value = SimpleNamespace(
            is_configured=True,
            secure_id_base_url='https://sandbox.cashfree.com/verification',
            client_id='id',
            client_secret='secret',
            api_version='2024-12-01',
        )
        response = SimpleNamespace(
            status_code=429,
            is_error=True,
            text='Too many requests',
            json=lambda: {
                'type': 'rate_limit_error',
                'code': 'too_many_requests_per_operation',
                'message': 'Too many requests for this operation, rate limit reached',
            },
        )
        client_mock.return_value.__enter__.return_value.post.return_value = response
        with self.assertRaises(CashfreeSecureIdError) as ctx:
            from services.providers.cashfree_secure_id import verify_bank_account

            verify_bank_account(bank_account='1234567890', ifsc='HDFC0001234')
        self.assertEqual(ctx.exception.code, 'rate_limit')

    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_fraud_account_from_bav_status(self, client_mock, settings_mock):
        settings_mock.return_value = SimpleNamespace(
            is_configured=True,
            secure_id_base_url='https://sandbox.cashfree.com/verification',
            client_id='id',
            client_secret='secret',
            api_version='2024-12-01',
        )
        response = SimpleNamespace(
            status_code=200,
            is_error=False,
            text='',
            json=lambda: {
                'account_status': 'INVALID',
                'account_status_code': 'FRAUD_ACCOUNT',
            },
        )
        client_mock.return_value.__enter__.return_value.post.return_value = response
        with self.assertRaises(CashfreeSecureIdError) as ctx:
            from services.providers.cashfree_secure_id import verify_bank_account

            verify_bank_account(bank_account='1234567890', ifsc='HDFC0001234')
        self.assertEqual(ctx.exception.code, 'fraud_account')


class CashfreeBypassDisabledTests(SimpleTestCase):
    @override_settings(CASHFREE_DEV_BYPASS=False, DEBUG=True, KYC_AUTO_APPROVE=True)
    def test_bypass_not_allowed_without_explicit_flag(self):
        from core.integrations.cashfree_bypass import sandbox_bypass_allowed

        self.assertFalse(sandbox_bypass_allowed())

    @override_settings(CASHFREE_DEV_BYPASS=True, DEBUG=False, KYC_AUTO_APPROVE=False)
    def test_bypass_allowed_only_when_explicitly_enabled(self):
        from core.integrations.cashfree_bypass import sandbox_bypass_allowed

        self.assertTrue(sandbox_bypass_allowed())

    @override_settings(KYC_BANK_PROVIDER='cashfree', CASHFREE_DEV_BYPASS=True)
    def test_kyc_bank_step_refuses_dev_bypass_flag(self):
        from kyc.service import _assert_live_provider_verification_only

        with self.assertRaises(CashfreeSecureIdError) as ctx:
            _assert_live_provider_verification_only('bank')
        self.assertEqual(ctx.exception.code, 'dev_bypass_disabled')


class KycModeTests(SimpleTestCase):
    @override_settings(
        KYC_PROVIDER='cashfree',
        KYC_PAN_PROVIDER='eko',
        KYC_BANK_PROVIDER='cashfree',
        KYC_UPI_PROVIDER='cashfree',
        KYC_UPI_REQUIRED=True,
        KYC_AADHAAR_PROVIDER='eko',
    )
    def test_mixed_providers_use_automated_mode(self):
        from kyc.providers import kyc_mode, upi_step_required

        self.assertEqual(kyc_mode(), 'automated')
        self.assertTrue(upi_step_required())

    @override_settings(KYC_UPI_PROVIDER='eko', KYC_UPI_REQUIRED=False)
    def test_upi_step_optional_when_disabled(self):
        from kyc.providers import upi_step_required

        self.assertFalse(upi_step_required())

    @override_settings(
        KYC_PROVIDER='cashfree',
        KYC_PAN_PROVIDER='',
        KYC_BANK_PROVIDER='',
        KYC_UPI_PROVIDER='',
        KYC_AADHAAR_PROVIDER='',
    )
    def test_legacy_cashfree_only_is_manual_mode(self):
        from kyc.providers import kyc_mode

        self.assertEqual(kyc_mode(), 'manual')


class FakeVerificationReferenceTests(SimpleTestCase):
    def test_sandbox_refs_are_not_really_verified(self):
        from kyc.models import KycProfile
        from kyc.service import _bank_really_verified, _is_fake_verification_reference, _upi_really_verified

        self.assertTrue(_is_fake_verification_reference('sandbox-4410'))
        self.assertTrue(_is_fake_verification_reference('soft_verify'))
        self.assertFalse(_is_fake_verification_reference('cf-ref-123'))

        profile = KycProfile(
            bank_status=KycProfile.VerificationStatus.VERIFIED,
            bank_reference_id='sandbox-4410',
            upi_status=KycProfile.VerificationStatus.VERIFIED,
            upi_reference_id='sandbox-3471',
        )
        self.assertFalse(_bank_really_verified(profile))
        self.assertFalse(_upi_really_verified(profile))


class AadhaarProviderGuardTests(SimpleTestCase):
    @override_settings(KYC_AADHAAR_PROVIDER='manual', KYC_PROVIDER='cashfree')
    def test_digilocker_rejects_unknown_aadhaar_provider(self):
        from kyc.models import KycProfile
        from kyc.service import start_aadhaar_digilocker_step

        user = SimpleNamespace(id=1, phone='9871013472', name='Test')
        with patch('kyc.service.get_or_create_profile') as profile_mock:
            profile_mock.return_value = SimpleNamespace(
                pan_status=KycProfile.VerificationStatus.VERIFIED,
                aadhaar_status=KycProfile.VerificationStatus.PENDING,
            )
            with self.assertRaises(EkoKycError) as ctx:
                start_aadhaar_digilocker_step(user)
        self.assertEqual(ctx.exception.code, 'unsupported_provider')

    @override_settings(KYC_AADHAAR_PROVIDER='cashfree', KYC_PROVIDER='cashfree')
    def test_cashfree_digilocker_start_creates_url(self):
        from kyc.models import KycProfile
        from kyc.service import start_aadhaar_digilocker_step

        user = SimpleNamespace(id=1, phone='9871013472', name='Test')
        profile = MagicMock()
        profile.pan_status = KycProfile.VerificationStatus.VERIFIED
        profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
        with patch('kyc.service.get_or_create_profile', return_value=profile), patch(
            'kyc.service.cashfree_settings'
        ) as cfg_mock, patch(
            'kyc.service._digilocker_redirect_url',
            return_value=('https://api.capitalbullwave.com/api/v1/digilocker/callback/st/', 'st'),
        ), patch(
            'kyc.service.cashfree_create_digilocker_url'
        ) as create_mock, patch(
            'kyc.service._audit'
        ):
            cfg_mock.return_value.is_configured = True
            create_mock.return_value = {
                'url': 'https://verification.cashfree.com/dl/abc',
                'reference_id': '99',
                'verification_id': 'vid-1',
                'status': 'PENDING',
            }
            result = start_aadhaar_digilocker_step(user)

        self.assertEqual(result.aadhaar_digilocker_url, 'https://verification.cashfree.com/dl/abc')
        self.assertEqual(result.aadhaar_reference_id, '99')
        self.assertEqual(result.aadhaar_status, KycProfile.VerificationStatus.PENDING)
        create_mock.assert_called_once()

    @override_settings(KYC_AADHAAR_PROVIDER='cashfree', KYC_PROVIDER='cashfree')
    def test_cashfree_digilocker_check_marks_verified(self):
        from kyc.models import KycProfile
        from kyc.service import check_aadhaar_digilocker_step

        user = SimpleNamespace(id=1, phone='9871013472', name='Gopal Kumar')
        profile = MagicMock()
        profile.pan_status = KycProfile.VerificationStatus.VERIFIED
        profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
        profile.aadhaar_reference_id = '99'
        profile.aadhaar_digilocker_client_ref_id = 'vid-1'
        profile.aadhaar_digilocker_verification_id = ''
        profile.pan_name = 'Gopal Kumar'
        with patch('kyc.service.get_or_create_profile', return_value=profile), patch(
            'kyc.service.cashfree_get_digilocker_identity'
        ) as identity_mock, patch('kyc.service._audit'), patch(
            'kyc.service._sync_user_name_from_kyc'
        ), patch('kyc.service._sync_user_dob_from_kyc'), patch(
            'kyc.service._update_overall_status'
        ):
            identity_mock.return_value = {
                'verification_status': 'SUCCESS',
                'verification_id': 'vid-1',
                'user_details': {
                    'name': 'Gopal Kumar',
                    'eaadhaar': 'Y',
                    'dob': '1990-01-15',
                    'aadhaar_number': 'XXXXXXXX1234',
                },
                'document_consent': [{'document_type': 'AADHAAR', 'consent': 'Y'}],
            }
            result = check_aadhaar_digilocker_step(user)

        self.assertEqual(result.aadhaar_status, KycProfile.VerificationStatus.VERIFIED)
        self.assertEqual(result.aadhaar_name, 'Gopal Kumar')
        self.assertEqual(result.aadhaar_last4, '1234')
        identity_mock.assert_called_once()


class CashfreeDigilockerApiTests(SimpleTestCase):
    def _cfg(self):
        return SimpleNamespace(
            is_configured=True,
            is_production=False,
            secure_id_base_url='https://sandbox.cashfree.com/verification',
            client_id='id',
            client_secret='secret',
            api_version='2024-12-01',
        )

    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_create_digilocker_url(self, client_mock, settings_mock):
        settings_mock.return_value = self._cfg()
        client_mock.return_value.__enter__.return_value.post.return_value = SimpleNamespace(
            status_code=200,
            is_error=False,
            text='',
            json=lambda: {
                'url': 'https://verification.cashfree.com/dl/x',
                'reference_id': 123,
                'verification_id': 'vid1',
                'status': 'PENDING',
            },
        )
        from services.providers.cashfree_secure_id import create_digilocker_url

        result = create_digilocker_url(
            verification_id='vid1',
            redirect_url='https://api.capitalbullwave.com/api/v1/digilocker/callback/st/',
        )
        self.assertEqual(result['url'], 'https://verification.cashfree.com/dl/x')
        self.assertEqual(result['reference_id'], '123')
        self.assertEqual(result['status'], 'PENDING')
        headers = client_mock.return_value.__enter__.return_value.post.call_args.kwargs['headers']
        self.assertEqual(headers['x-api-version'], '2023-12-18')

    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_get_identity_after_authenticated(self, client_mock, settings_mock):
        settings_mock.return_value = self._cfg()
        http = client_mock.return_value.__enter__.return_value
        http.get.side_effect = [
            SimpleNamespace(
                status_code=200,
                is_error=False,
                text='',
                json=lambda: {'status': 'AUTHENTICATED', 'verification_id': 'vid1', 'reference_id': 123},
            ),
            SimpleNamespace(
                status_code=200,
                is_error=False,
                text='',
                json=lambda: {
                    'name': 'Gopal Kumar',
                    'dob': '1990-01-15',
                    'aadhaar_number': 'XXXXXXXX1234',
                },
            ),
        ]
        from services.providers.cashfree_secure_id import get_digilocker_identity

        result = get_digilocker_identity(verification_id='vid1')
        self.assertEqual(result['verification_status'], 'SUCCESS')
        self.assertEqual(result['user_details']['name'], 'Gopal Kumar')
        self.assertEqual(result['user_details']['aadhaar_number'], 'XXXXXXXX1234')

    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_get_identity_stays_pending(self, client_mock, settings_mock):
        settings_mock.return_value = self._cfg()
        client_mock.return_value.__enter__.return_value.get.return_value = SimpleNamespace(
            status_code=200,
            is_error=False,
            text='',
            json=lambda: {'status': 'PENDING', 'verification_id': 'vid1'},
        )
        from services.providers.cashfree_secure_id import get_digilocker_identity

        result = get_digilocker_identity(verification_id='vid1')
        self.assertEqual(result['verification_status'], 'PENDING')
        self.assertEqual(result['user_details'], {})

    @patch('services.providers.cashfree_secure_id.cashfree_settings')
    @patch('services.providers.cashfree_secure_id.httpx.Client')
    def test_create_url_maps_generic_500(self, client_mock, settings_mock):
        settings_mock.return_value = self._cfg()
        client_mock.return_value.__enter__.return_value.post.return_value = SimpleNamespace(
            status_code=500,
            is_error=True,
            text='{"message":"something went wrong, please try after some time"}',
            json=lambda: {
                'type': 'internal_error',
                'code': 'verification_failed',
                'message': 'something went wrong, please try after some time',
            },
        )
        from services.providers.cashfree_secure_id import create_digilocker_url

        with self.assertRaises(CashfreeSecureIdError) as ctx:
            create_digilocker_url(
                verification_id='vid1',
                redirect_url='https://api.capitalbullwave.com/api/v1/digilocker/return/',
            )
        self.assertEqual(ctx.exception.code, 'digilocker_unavailable')
        self.assertIn('sandbox.cashfree.com', str(ctx.exception))
        self.assertGreaterEqual(client_mock.return_value.__enter__.return_value.post.call_count, 2)


class CashfreeTestKeyRoutingTests(SimpleTestCase):
    @override_settings(
        CASHFREE_CLIENT_ID='TEST111332480f0ed98d8cc715d0879284233111',
        CASHFREE_CLIENT_SECRET='cfsk_ma_test_example',
        CASHFREE_ENVIRONMENT='production',
        CASHFREE_ENV='production',
        SECURE_ID_BASE_URL='https://api.cashfree.com/verification',
        CASHFREE_API_VERSION='2024-12-01',
        CASHFREE_PAYMENT_API_VERSION='2023-08-01',
        CASHFREE_PAYMENTS_BASE_URL='',
        CASHFREE_PAYOUTS_BASE_URL='',
        CASHFREE_PAYMENT_WEBHOOK_SECRET='',
        CASHFREE_PAYOUT_WEBHOOK_SECRET='',
        CASHFREE_WEBHOOK_SECRET='',
        SECURE_ID_API_KEY='',
        SECURE_ID_API_SECRET='',
    )
    def test_test_keys_force_sandbox_host(self):
        from services.providers.cashfree_config import cashfree_settings

        cfg = cashfree_settings()
        self.assertFalse(cfg.is_production)
        self.assertEqual(cfg.environment, 'sandbox')
        self.assertEqual(cfg.secure_id_base_url, 'https://sandbox.cashfree.com/verification')
