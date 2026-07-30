from unittest.mock import patch

from django.test import TestCase, override_settings
from django.utils import timezone

from accounts.models import User
from kyc.models import KycProfile
from kyc.service import verify_bank_step


@override_settings(DEBUG=False, KYC_BANK_REVIEW_MODE='provider', KYC_BANK_PROVIDER='eko')
class BankIdentityMatchTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9876543210', name='Gopal Kumar')
        self.profile = KycProfile.objects.create(
            user=self.user,
            mobile_verified=True,
            pan_number='ABCDE1234F',
            pan_name='GOPAL KUMAR',
            pan_status=KycProfile.VerificationStatus.VERIFIED,
            pan_verified_at=timezone.now(),
        )

    @patch('kyc.service._verify_bank')
    def test_rejects_third_party_bank_account(self, verify_mock):
        verify_mock.return_value = {
            'reference_id': 'REF1',
            'utr': 'UTR1',
            'account_status': 'VALID',
            'account_status_code': 'ACCOUNT_IS_VALID',
            'name_at_bank': 'RAHUL SHARMA',
            'bank_name': 'HDFC Bank',
            'branch': 'Mumbai',
            'verification_method': 'penniless',
        }

        with self.assertRaises(ValueError) as raised:
            verify_bank_step(
                self.user,
                account_holder_name='GOPAL KUMAR',
                account_number='123456789012',
                confirm_account_number='123456789012',
                ifsc='HDFC0001234',
            )

        self.assertIn('not in your name', str(raised.exception).lower())
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.bank_status, KycProfile.VerificationStatus.FAILED)
        self.assertFalse(self.profile.name_match_passed)

    @patch('kyc.service._verify_bank')
    def test_accepts_matching_bank_account(self, verify_mock):
        verify_mock.return_value = {
            'reference_id': 'REF2',
            'utr': 'UTR2',
            'account_status': 'VALID',
            'account_status_code': 'ACCOUNT_IS_VALID',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'Punjab National Bank',
            'branch': 'Delhi',
            'verification_method': 'penniless',
        }

        profile = verify_bank_step(
            self.user,
            account_holder_name='GOPAL KUMAR',
            account_number='123456789012',
            confirm_account_number='123456789012',
            ifsc='HDFC0001234',
        )

        self.assertEqual(profile.bank_status, KycProfile.VerificationStatus.VERIFIED)
        self.assertTrue(profile.name_match_passed)
        self.assertEqual(profile.name_at_bank, 'GOPAL KUMAR')

    @patch('kyc.service._verify_bank')
    def test_uses_pan_name_when_holder_name_omitted(self, verify_mock):
        verify_mock.return_value = {
            'reference_id': 'REF3',
            'name_at_bank': 'GOPAL KUMAR',
            'bank_name': 'PNB',
            'verification_method': 'penniless',
        }

        verify_bank_step(
            self.user,
            account_holder_name='',
            account_number='123456789012',
            confirm_account_number='123456789012',
            ifsc='HDFC0001234',
        )

        verify_mock.assert_called_once()
        self.assertEqual(verify_mock.call_args.kwargs['name'], 'GOPAL KUMAR')

    @override_settings(KYC_BANK_SKIP_IDENTITY_MATCH=True)
    @patch('kyc.service._verify_bank')
    def test_skip_identity_match_allows_third_party_account(self, verify_mock):
        verify_mock.return_value = {
            'reference_id': 'REF4',
            'name_at_bank': 'RAHUL SHARMA',
            'bank_name': 'HDFC Bank',
            'verification_method': 'penniless',
        }

        profile = verify_bank_step(
            self.user,
            account_holder_name='RAHUL SHARMA',
            account_number='123456789012',
            confirm_account_number='123456789012',
            ifsc='HDFC0001234',
        )

        self.assertEqual(profile.bank_status, KycProfile.VerificationStatus.VERIFIED)
        self.assertEqual(profile.name_at_bank, 'RAHUL SHARMA')
