from types import SimpleNamespace
from unittest.mock import patch

from django.test import SimpleTestCase, override_settings

from services.eko_bank import (
    EkoBankError,
    is_bank_verification_successful,
    verify_bank_account,
    verify_bank_account_penny_drop,
    verify_bank_account_penniless,
)


def _valid_bank_data(**overrides):
    data = {
        'account_status': 'VALID',
        'account_status_code': 'ACCOUNT_IS_VALID',
        'name_at_bank': 'GOPAL KUMAR',
        'bank_name': 'Punjab National Bank',
        'branch': 'TEST',
        'reference_id': 'REF123',
        'utr': 'UTR123',
    }
    data.update(overrides)
    return data


def _valid_envelope(**overrides):
    envelope = {
        'response_status_id': 0,
        'status': 0,
        'message': 'Success',
    }
    envelope.update(overrides)
    return envelope


class EkoBankModuleTests(SimpleTestCase):
    def test_success_requires_all_status_fields(self):
        ok, reason = is_bank_verification_successful(
            _valid_envelope(),
            _valid_bank_data(),
        )
        self.assertTrue(ok)
        self.assertEqual(reason, '')

        ok, reason = is_bank_verification_successful(
            _valid_envelope(response_status_id=1),
            _valid_bank_data(),
        )
        self.assertFalse(ok)
        self.assertTrue(reason)

        ok, reason = is_bank_verification_successful(
            _valid_envelope(),
            _valid_bank_data(account_status='INVALID'),
        )
        self.assertFalse(ok)

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_rejects_submitted_name_not_matching_bank_records(self, settings_mock, post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        post_mock.return_value = (
            _valid_envelope(),
            _valid_bank_data(name_at_bank='RAHUL SHARMA'),
        )

        with self.assertRaises(EkoBankError) as raised:
            verify_bank_account_penny_drop(
                account_number='0944100100008944',
                ifsc='PUNB0094410',
                account_holder_name='GOPAL KUMAR',
            )

        self.assertEqual(raised.exception.code, 'name_mismatch')

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_penniless_uses_configured_path(self, settings_mock, post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
            penniless_configured=True,
            penniless_path='/v3/tools/kyc/touras/bank-acc-verify-penniless',
        )
        post_mock.return_value = (_valid_envelope(), _valid_bank_data(transaction_id='TXN123'))

        result = verify_bank_account_penniless(
            account_number='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penniless')
        self.assertEqual(post_mock.call_args.args[0], '/v3/tools/kyc/touras/bank-acc-verify-penniless')
        payload = post_mock.call_args.args[1]
        self.assertEqual(payload['account'], '0944100100008944')

    @patch('services.eko_bank.eko_post_json')
    @patch('services.eko_bank.eko_settings')
    def test_penny_drop_uses_v3_json_api(self, settings_mock, post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )
        post_mock.return_value = (_valid_envelope(), _valid_bank_data())

        result = verify_bank_account_penny_drop(
            account_number='0944100100008944',
            ifsc='PUNB0094410',
            account_holder_name='GOPAL KUMAR',
        )

        self.assertEqual(result['reference_id'], 'REF123')
        self.assertEqual(result['utr'], 'UTR123')
        self.assertEqual(result['verification_method'], 'penny_drop')
        self.assertEqual(post_mock.call_args.args[0], '/v3/tools/kyc/bank-account/sync')

    @patch('services.eko_bank.eko_post_json', return_value=({}, {}))
    @patch('services.eko_bank.eko_settings')
    def test_empty_response_is_treated_as_invalid(self, settings_mock, _post_mock):
        settings_mock.return_value = SimpleNamespace(
            initiator_id='9999999999',
            user_code='USER1',
            org_slug='',
        )

        with self.assertRaises(EkoBankError) as raised:
            verify_bank_account_penny_drop(
                account_number='0944100100008944',
                ifsc='PUNB0094410',
                account_holder_name='GOPAL KUMAR',
            )

        self.assertEqual(raised.exception.code, 'invalid_account')

    @patch('services.eko_bank.verify_bank_account_penny_drop')
    @patch('services.eko_bank.verify_bank_account_penniless')
    @patch('services.eko_bank.eko_settings')
    def test_prefers_penniless_when_enabled(self, settings_mock, penniless_mock, penny_drop_mock):
        settings_mock.return_value = SimpleNamespace(
            penniless_enabled=True,
            penniless_configured=True,
        )
        penniless_mock.return_value = {
            'reference_id': 'PL123',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'Punjab National Bank',
            'verification_method': 'penniless',
        }

        result = verify_bank_account(
            account_number='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penniless')
        penniless_mock.assert_called_once()
        penny_drop_mock.assert_not_called()

    @patch('services.eko_bank.verify_bank_account_penny_drop')
    @patch('services.eko_bank.verify_bank_account_penniless')
    @patch('services.eko_bank.eko_settings')
    def test_falls_back_to_penny_drop(self, settings_mock, penniless_mock, penny_drop_mock):
        settings_mock.return_value = SimpleNamespace(
            penniless_enabled=True,
            penniless_configured=True,
        )
        penniless_mock.side_effect = EkoBankError(
            'Bank is not enabled for PennyLess. Please use Penny Drop API.',
            'penniless_unavailable',
        )
        penny_drop_mock.return_value = {
            'reference_id': 'UTR123',
            'name_at_bank': 'GOPAL KUMAR',
            'verification_method': 'penny_drop',
        }

        result = verify_bank_account(
            account_number='0944100100008944',
            ifsc='PUNB0094410',
        )

        self.assertEqual(result['verification_method'], 'penny_drop')
        penny_drop_mock.assert_called_once()
