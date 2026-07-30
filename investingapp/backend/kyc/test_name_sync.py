from unittest.mock import patch

from django.test import TestCase

from accounts.models import User
from kyc.models import KycProfile
from kyc.service import verify_pan_step


class KycUserNameSyncTests(TestCase):
    @patch('kyc.service._verify_pan')
    def test_pan_verification_updates_user_display_name(self, verify_pan_mock):
        verify_pan_mock.return_value = {
            'reference_id': 'PAN123',
            'registered_name': 'SAKSHI BISHT',
            'valid': True,
        }
        user = User.objects.create(phone='9876543210', name='Gopal', email='test@example.com')

        verify_pan_step(user, 'ABCDE1234F')

        user.refresh_from_db()
        profile = KycProfile.objects.get(user=user)
        self.assertEqual(user.name, 'Sakshi Bisht')
        self.assertEqual(profile.pan_name, 'SAKSHI BISHT')
        self.assertEqual(profile.account_holder_name, 'Sakshi Bisht')
