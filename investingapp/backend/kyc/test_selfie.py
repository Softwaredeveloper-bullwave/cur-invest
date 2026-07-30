from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from kyc.models import KycProfile
from kyc.selfie_service import SelfieError, approve_selfie, upload_selfie

User = get_user_model()


def _make_image(name='selfie.jpg'):
    return SimpleUploadedFile(name, b'\xff\xd8\xff' + b'0' * 128, content_type='image/jpeg')


@override_settings(KYC_UPI_REQUIRED=False)
class SelfieServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='919900001111', password='test-pass-123')
        self.profile = KycProfile.objects.create(
            user=self.user,
            mobile_verified=True,
            pan_status=KycProfile.VerificationStatus.VERIFIED,
            aadhaar_status=KycProfile.VerificationStatus.VERIFIED,
            bank_status=KycProfile.VerificationStatus.VERIFIED,
            bank_reference_id='live-bank-ref',
        )
        self.admin = User.objects.create_user(
            phone='919900002222',
            password='test-pass-123',
            is_staff=True,
        )

    def test_upload_requires_bank_verified(self):
        self.profile.bank_status = KycProfile.VerificationStatus.PENDING
        self.profile.save(update_fields=['bank_status'])
        with self.assertRaises(SelfieError):
            upload_selfie(self.user, _make_image())

    def test_upload_marks_completed_and_pending_review(self):
        profile = upload_selfie(self.user, _make_image())
        self.assertEqual(profile.selfie_status, KycProfile.SelfieStatus.COMPLETED)
        self.assertTrue(profile.selfie_image)
        self.assertIsNotNone(profile.selfie_review_due_at)

    def test_admin_approve_marks_verified(self):
        upload_selfie(self.user, _make_image())
        profile = approve_selfie(self.profile, self.admin, note='Looks good')
        self.assertEqual(profile.selfie_status, KycProfile.SelfieStatus.VERIFIED)


@override_settings(KYC_UPI_REQUIRED=False)
class UploadSelfieApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='919900009999', password='test-pass-123')
        KycProfile.objects.create(
            user=self.user,
            mobile_verified=True,
            pan_status=KycProfile.VerificationStatus.VERIFIED,
            aadhaar_status=KycProfile.VerificationStatus.VERIFIED,
            bank_status=KycProfile.VerificationStatus.VERIFIED,
            bank_reference_id='live-bank-ref',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_upload_selfie_endpoint(self):
        res = self.client.post(
            '/api/v1/upload-selfie/',
            {'selfie': _make_image()},
            format='multipart',
        )
        self.assertEqual(res.status_code, 201)
        self.assertTrue(res.data.get('success'))
        self.assertEqual(res.data.get('message'), 'Selfie uploaded successfully.')
        self.assertEqual(res.data.get('selfieStatus'), 'completed')
        self.assertTrue(res.data.get('selfieReviewPending'))
