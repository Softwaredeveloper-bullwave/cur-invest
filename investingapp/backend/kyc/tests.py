from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings

from services.eko_bank import EkoBankError
from services.providers.eko_kyc import (
    EkoKycError,
    _provider_error,
    create_digilocker_url,
    get_digilocker_status,
    onboard_sender,
    verify_bank_account,
    verify_bank_account_penny_drop,
    verify_bank_account_penniless,
)

from .aadhaar_security import decrypt_aadhaar, encrypt_aadhaar
from .masking import mask_aadhaar
from .serializers import SendAadhaarOtpSerializer
from .service import _digilocker_aadhaar_consent, _digilocker_redirect_url, digilocker_app_return_url


class AadhaarInputTests(SimpleTestCase):
    def test_accepts_valid_verhoeff_checksum(self):
        serializer = SendAadhaarOtpSerializer(data={'aadhaar_number': '999999990019'})

        self.assertTrue(serializer.is_valid(), serializer.errors)

    def test_rejects_invalid_verhoeff_checksum(self):
        serializer = SendAadhaarOtpSerializer(data={'aadhaar_number': '234567890123'})

        self.assertFalse(serializer.is_valid())
        self.assertIn('aadhaar_number', serializer.errors)

    def test_masks_last_four_without_full_number(self):
        self.assertEqual(mask_aadhaar('0019'), 'XXXX XXXX 0019')


@override_settings(DEBUG=True, SECRET_KEY='test-secret', AADHAAR_ENCRYPTION_KEY='')
class AadhaarEncryptionTests(SimpleTestCase):
    def test_round_trip_does_not_store_plaintext(self):
        encrypted = encrypt_aadhaar('999999990019')

        self.assertNotIn('999999990019', encrypted)
        self.assertEqual(decrypt_aadhaar(encrypted), '999999990019')


class EkoSenderPayloadTests(SimpleTestCase):
    def test_customer_not_allowed_has_actionable_error(self):
        error = _provider_error('Customer not allowed', '1')

        self.assertEqual(error.code, 'service_not_active')
        self.assertIn('whitelist', str(error))

    @patch('services.providers.eko_kyc._request')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_sender_onboarding_uses_service_80_and_address_array(self, settings_mock, request_mock):
        settings_mock.return_value = SimpleNamespace(initiator_id='9999999999', user_code='USER1')
        request_mock.return_value = {'otp_ref_id': 'ref-1'}

        result = onboard_sender(
            mobile='9876543210',
            name='Test User',
            dob='1990-01-01',
            address={'line': '12 Test Road', 'city': 'Mumbai', 'pincode': '400001'},
        )

        self.assertEqual(result['otp_ref_id'], 'ref-1')
        payload = request_mock.call_args.args[2]
        self.assertEqual(payload['service_code'], 80)
        self.assertEqual(payload['residence_address'], '["12 Test Road", "Mumbai", "400001"]')


class EkoDigiLockerTests(SimpleTestCase):
    @patch('services.providers.eko_kyc._request')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_create_url_requests_only_aadhaar(self, settings_mock, request_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        request_mock.return_value = {
            'url': 'https://digilocker.example/session',
            'reference_id': 12345,
        }

        result = create_digilocker_url(
            client_ref_id='DL-1',
            redirect_url='https://api.example.com/callback',
        )

        self.assertEqual(result['reference_id'], '12345')
        payload = request_mock.call_args.args[2]
        self.assertEqual(payload['document_requested'], ['AADHAAR'])
        self.assertTrue(request_mock.call_args.kwargs['json_body'])
        self.assertFalse(request_mock.call_args.kwargs['check_status'])

    @patch('services.providers.eko_kyc._get')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_status_prefers_verification_id(self, settings_mock, get_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        get_mock.return_value = {
            'status': 'SUCCESS',
            'user_details': {'name': 'Test User', 'eaadhaar': 'Y'},
            'document_consent': [{'document_type': 'AADHAAR', 'consent': 'Y'}],
            'verification_id': '3571170546',
        }

        result = get_digilocker_status(
            reference_id='7393672',
            verification_id='3571170546',
        )

        self.assertEqual(result['verification_status'], 'SUCCESS')
        first_call_params = get_mock.call_args_list[0].args[1]
        self.assertEqual(first_call_params.get('verification_id'), '3571170546')

    @patch('services.providers.eko_kyc._get')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_status_normalizes_verified_identity(self, settings_mock, get_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        get_mock.return_value = {
            'verification_status': 'success',
            'user_details': {'name': 'Test User', 'eaadhaar': 'Y'},
            'document_consent': [{'document_type': 'AADHAAR', 'consent': 'Y'}],
        }

        result = get_digilocker_status(reference_id='12345')

        self.assertEqual(result['verification_status'], 'SUCCESS')
        self.assertEqual(result['user_details']['name'], 'Test User')

    @patch('services.providers.eko_kyc._request')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_document_fetch_uses_form_body(self, settings_mock, request_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        request_mock.return_value = {
            'name': 'Test User',
            'dob': '15-08-1990',
            'gender': 'M',
            'reference_id': 12345,
        }

        from services.providers.eko_kyc import fetch_digilocker_document

        result = fetch_digilocker_document(
            reference_id='12345',
            verification_id='3571170546',
            client_ref_id='abc123',
        )

        self.assertEqual(result['verification_status'], 'SUCCESS')
        self.assertEqual(result['user_details']['name'], 'Test User')
        self.assertFalse(request_mock.call_args.kwargs['json_body'])
        payload = request_mock.call_args.args[2]
        self.assertEqual(payload['document_type'], 'AADHAAR')

    @patch('services.providers.eko_kyc._request')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_document_fetch_raises_session_expired(self, settings_mock, request_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        request_mock.return_value = {
            'response_status_id': 1,
            'code': 'session_expired',
            'message': 'Digilocker consent session expired',
        }

        from services.providers.eko_kyc import fetch_digilocker_document

        with self.assertRaises(EkoKycError) as ctx:
            fetch_digilocker_document(
                reference_id='12345',
                verification_id='3571170546',
                client_ref_id='abc123',
            )
        self.assertIn('expired', str(ctx.exception).lower())

    def test_aadhaar_consent_parser(self):
        self.assertTrue(
            _digilocker_aadhaar_consent(
                [{'document_type': 'AADHAAR', 'consent': 'Y'}]
            )
        )


class DigiLockerRedirectTests(SimpleTestCase):
    @override_settings(
        BACKEND_PUBLIC_URL='https://api.bullwave.in',
        EKO_DIGILOCKER_REDIRECT_URL='',
        APP_SHARE_URL='https://bullwave.in',
    )
    def test_prefers_https_backend_callback(self):
        redirect_url, state = _digilocker_redirect_url()
        self.assertTrue(redirect_url.startswith('https://api.bullwave.in/api/v1/digilocker/callback/'))
        self.assertTrue(state)

    @override_settings(
        BACKEND_PUBLIC_URL='http://127.0.0.1:8000',
        LOCAL_DEV_TUNNEL_URL='https://bright-fish-42.loca.lt',
        EKO_DIGILOCKER_REDIRECT_URL='',
        APP_SHARE_URL='https://bullwave.in',
    )
    def test_uses_local_tunnel_when_backend_is_http(self):
        redirect_url, state = _digilocker_redirect_url()
        self.assertTrue(redirect_url.startswith('https://bright-fish-42.loca.lt/api/v1/digilocker/callback/'))
        self.assertTrue(state)

    @override_settings(
        BACKEND_PUBLIC_URL='http://127.0.0.1:8000',
        LOCAL_DEV_TUNNEL_URL='',
        EKO_DIGILOCKER_REDIRECT_URL='https://bullwave.in',
        APP_SHARE_URL='https://bullwave.in',
    )
    def test_rejects_marketing_redirect(self):
        with self.assertRaises(EkoKycError):
            _digilocker_redirect_url()

    @override_settings(APP_WEB_URL='http://localhost:58076')
    def test_app_return_url_includes_verification_id(self):
        url = digilocker_app_return_url(verification_id='3571170546')
        self.assertIn('digilocker=1', url)
        self.assertIn('verification_id=3571170546', url)
        self.assertTrue(url.startswith('http://localhost:58076/#/kyc/aadhaar?'))


class EkoBankVerificationTests(SimpleTestCase):
    @patch('services.eko_bank.verify_bank_account_penny_drop')
    @patch('services.eko_bank.verify_bank_account_penniless')
    @patch('services.eko_bank.eko_settings')
    def test_prefers_penniless_when_enabled(self, settings_mock, penniless_mock, penny_drop_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
            penniless_enabled=True,
            penniless_configured=True,
            penniless_path='/v3/tools/kyc/touras/bank-acc-verify-penniless',
        )
        penniless_mock.return_value = {
            'reference_id': 'PL123',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'Punjab National Bank',
            'branch': 'TEST',
            'verification_method': 'penniless',
        }

        result = verify_bank_account(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penniless')
        penniless_mock.assert_called_once()
        penny_drop_mock.assert_not_called()

    @patch('services.eko_bank.verify_bank_account_penny_drop')
    @patch('services.eko_bank.verify_bank_account_penniless')
    @patch('services.eko_bank.eko_settings')
    def test_falls_back_to_penny_drop_when_penniless_unavailable(
        self, settings_mock, penniless_mock, penny_drop_mock
    ):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
            penniless_enabled=True,
            penniless_configured=True,
            penniless_path='/v3/tools/kyc/touras/bank-acc-verify-penniless',
        )
        penniless_mock.side_effect = EkoBankError(
            'Bank is not enabled for PennyLess. Please use Penny Drop API.',
            'penniless_unavailable',
        )
        penny_drop_mock.return_value = {
            'reference_id': 'UTR123',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'Punjab National Bank',
            'branch': 'TEST',
            'verification_method': 'penny_drop',
        }

        result = verify_bank_account(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penny_drop')
        penny_drop_mock.assert_called_once()

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_penniless_uses_configured_path_and_account_field(self, settings_mock, post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
            penniless_configured=True,
            penniless_path='/v3/tools/kyc/touras/bank-acc-verify-penniless',
        )
        post_mock.return_value = (
            {
                'response_status_id': 0,
                'status': 0,
                'message': 'Success',
            },
            {
                'account_status': 'VALID',
                'account_status_code': 'ACCOUNT_IS_VALID',
                'name_at_bank': 'GOPAL KUMAR',
                'bank_name': 'Punjab National Bank',
                'branch': 'TEST',
                'transaction_id': 'TXN123',
            },
        )

        result = verify_bank_account_penniless(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penniless')
        self.assertEqual(post_mock.call_args.args[0], '/v3/tools/kyc/touras/bank-acc-verify-penniless')
        payload = post_mock.call_args.args[1]
        self.assertEqual(payload['account'], '0944100100008944')
        self.assertEqual(payload['user_code'], 'USER1')

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_penny_drop_uses_v3_json_api(self, settings_mock, post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        post_mock.return_value = (
            {
                'response_status_id': 0,
                'status': 0,
                'message': 'Success',
            },
            {
                'account_status': 'VALID',
                'account_status_code': 'ACCOUNT_IS_VALID',
                'name_at_bank': 'GOPAL KUMAR',
                'bank_name': 'Punjab National Bank',
                'branch': 'TEST',
                'utr': 'UTR123',
            },
        )

        result = verify_bank_account_penny_drop(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
            name='GOPAL KUMAR',
        )

        self.assertEqual(result['reference_id'], 'UTR123')
        self.assertEqual(result['name_at_bank'], 'GOPAL KUMAR')
        self.assertEqual(result['verification_method'], 'penny_drop')
        self.assertEqual(post_mock.call_args.args[0], '/v3/tools/kyc/bank-account/sync')
        payload = post_mock.call_args.args[1]
        self.assertEqual(payload['bank_account'], '0944100100008944')
        self.assertEqual(payload['user_code'], 'USER1')
        self.assertLessEqual(len(payload['client_ref_id']), 20)

    @patch('services.eko_bank.eko_post_json', return_value=({}, {}))
    @patch('services.eko_bank.eko_settings')
    def test_empty_connect_response_reports_invalid_account(self, settings_mock, _post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )

        with self.assertRaises(EkoKycError) as raised:
            verify_bank_account_penny_drop(
                bank_account='0944100100008944',
                ifsc='PUNB0094410',
                name='GOPAL KUMAR',
            )

        self.assertEqual(raised.exception.code, 'invalid_account')

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_penniless_accepts_valid_account_status_without_account_exists(
        self, settings_mock, post_mock
    ):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='touras',
            penniless_configured=True,
            penniless_path='',
        )
        post_mock.return_value = (
            {
                'response_status_id': 0,
                'status': 0,
                'message': 'Success',
            },
            {
                'account_status': 'VALID',
                'account_status_code': 'ACCOUNT_IS_VALID',
                'name_at_bank': 'GOPAL KUMAR',
                'bank_name': 'Punjab National Bank',
                'branch': 'TEST',
                'transaction_id': 'TXN123',
            },
        )

        result = verify_bank_account_penniless(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penniless')
        self.assertEqual(result['name_at_bank'], 'GOPAL KUMAR')
        self.assertEqual(
            post_mock.call_args.args[0],
            '/v3/tools/kyc/touras/bank-acc-verify-penniless',
        )

    @patch('services.eko_bank.verify_bank_account_penny_drop')
    @patch('services.eko_bank.verify_bank_account_penniless')
    @patch('services.eko_bank.eko_settings')
    def test_skips_penniless_when_not_configured(self, settings_mock, penniless_mock, penny_drop_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
            penniless_enabled=True,
            penniless_configured=False,
            penniless_path='',
        )
        penny_drop_mock.return_value = {
            'reference_id': 'UTR123',
            'name_at_bank': 'GOPAL KUMAR',
            'verification_method': 'penny_drop',
        }

        result = verify_bank_account(
            bank_account='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penny_drop')
        penniless_mock.assert_not_called()
        penny_drop_mock.assert_called_once()


class EkoPanVerificationTests(SimpleTestCase):
    @patch('services.providers.eko_kyc._request')
    @patch('services.providers.eko_kyc.eko_settings')
    def test_verify_pan_success_legacy_envelope(self, settings_mock, request_mock):
        settings_mock.return_value = SimpleNamespace(initiator_id='9999999999', user_code='USER1')
        request_mock.return_value = {
            'pan_number': 'KCOPK2284L',
            'pan_returned_name': 'GOPAL KUMAR',
            '_eko_message': 'PAN verification successful',
            '_eko_response_status_id': -1,
            '_eko_response_type_id': 1255,
            '_eko_status': 0,
        }

        from services.providers.eko_kyc import verify_pan

        result = verify_pan('KCOPK2284L', 'Gopal Kumar')

        self.assertTrue(result['valid'])
        self.assertEqual(result['registered_name'], 'GOPAL KUMAR')
        self.assertEqual(result['reference_id'], 'KCOPK2284L')

    @patch('services.providers.eko_kyc._request')
    def test_verify_pan_rejects_business_failure_inside_http_200(self, request_mock):
        request_mock.side_effect = EkoKycError(
            'PAN verification response not received',
            '1',
            eko_meta={
                'message': 'PAN verification response not received',
                'responseStatusId': 1,
                'responseTypeId': 1254,
                'status': 0,
                'referenceId': '',
            },
        )

        from services.providers.eko_kyc import verify_pan

        with self.assertRaises(EkoKycError) as ctx:
            verify_pan('KCOPK2284L', 'Gopal Kumar')

        self.assertEqual(ctx.exception.code, '1')
        self.assertEqual(ctx.exception.eko_meta['responseTypeId'], 1254)

    @patch('services.providers.eko_kyc._request')
    def test_verify_pan_rejects_success_envelope_without_holder_name(self, request_mock):
        request_mock.return_value = {
            'pan_number': 'KCOPK2284L',
            '_eko_message': 'PAN verification successful',
            '_eko_response_status_id': -1,
            '_eko_response_type_id': 1255,
            '_eko_status': 0,
        }

        from services.providers.eko_kyc import verify_pan

        with self.assertRaises(EkoKycError) as ctx:
            verify_pan('KCOPK2284L', 'Gopal Kumar')

        self.assertEqual(ctx.exception.code, '-1')
        self.assertIn('PAN verification successful', ctx.exception.eko_meta['message'])

    def test_evaluate_eko_status_rejects_response_status_id_one_even_when_status_zero(self):
        from services.providers.eko_kyc import _evaluate_eko_status

        with self.assertRaises(EkoKycError) as ctx:
            _evaluate_eko_status(
                {
                    'message': 'PAN verification response not received',
                    'response_status_id': 1,
                    'response_type_id': 1254,
                    'status': 0,
                    'data': {},
                },
                check_status=True,
            )

        self.assertEqual(ctx.exception.code, '1')
        self.assertEqual(ctx.exception.eko_meta['responseStatusId'], 1)
        self.assertEqual(ctx.exception.eko_meta['responseTypeId'], 1254)

    def test_sanitize_eko_payload_masks_pan_for_debug_logs(self):
        from services.providers.eko_kyc import _sanitize_eko_payload_for_log

        cleaned = _sanitize_eko_payload_for_log(
            {
                'message': 'ok',
                'data': {'pan_number': 'KCOPK2284L', 'developer_key': 'secret'},
            }
        )

        self.assertEqual(cleaned['data']['pan_number'], 'KC*****4L')
        self.assertEqual(cleaned['data']['developer_key'], '***')
