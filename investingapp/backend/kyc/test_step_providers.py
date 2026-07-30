from types import SimpleNamespace
from unittest.mock import patch

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
    @override_settings(KYC_AADHAAR_PROVIDER='cashfree', KYC_PROVIDER='cashfree')
    def test_digilocker_requires_eko_aadhaar_provider(self):
        from kyc.models import KycProfile
        from kyc.service import start_aadhaar_digilocker_step

        user = SimpleNamespace(id=1, phone='9871013472', name='Test')
        with patch('kyc.service.get_or_create_profile') as profile_mock:
            profile_mock.return_value = SimpleNamespace(
                pan_status=KycProfile.VerificationStatus.VERIFIED,
                aadhaar_status=KycProfile.VerificationStatus.PENDING,
            )
            with self.assertRaises(EkoKycError):
                start_aadhaar_digilocker_step(user)
