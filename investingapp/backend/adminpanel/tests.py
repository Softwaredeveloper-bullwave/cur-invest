from datetime import timedelta

from django.test import override_settings
from django.core.management import call_command
from django.utils import timezone
from rest_framework.test import APITestCase

from accounts.models import BankAccount, User
from kyc.models import BankVerificationRequest, KycProfile
from core.error_reporting import record_error_event
from engagement.models import Notification, SupportTicket
from .models import AdminBroadcast, ApplicationErrorEvent


@override_settings(KYC_BANK_REVIEW_MODE='manual', ADMIN_PANEL_DEV_NO_AUTH=False)
class AdminPanelBankReviewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(phone='9000000001', name='Admin', is_staff=True)
        self.admin.set_password('Strong-Test-Password-123!')
        self.admin.save(update_fields=['password'])
        self.user = User.objects.create_user(phone='9000000002', name='Test User')
        self.profile = KycProfile.objects.create(
            user=self.user,
            mobile_verified=True,
            pan_number='ABCDE1234F',
            pan_name='Test User',
            pan_status=KycProfile.VerificationStatus.VERIFIED,
            pan_verified_at=timezone.now(),
        )

    def _submit_bank(self):
        self.client.force_authenticate(self.user)
        response = self.client.post(
            '/api/v1/verify-bank/',
            {
                'account_number': '12345678901',
                'confirm_account_number': '12345678901',
                'account_holder_name': 'Test User',
                'ifsc': 'HDFC0001234',
            },
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data.get('bankDraftReady'))
        return response.data

    def _submit_payment_review(self):
        self._submit_bank()
        response = self.client.post(
            '/api/v1/verify-upi/',
            {'upi_vpa': 'testuser@upi', 'recipient_mobile': '9000000002'},
            format='json',
        )
        self.assertEqual(response.status_code, 202, response.data)
        return BankVerificationRequest.objects.get(user=self.user)

    def test_bank_submission_is_pending_for_24_hour_manual_review(self):
        row = self._submit_payment_review()
        self.profile.refresh_from_db()
        self.assertEqual(row.status, BankVerificationRequest.Status.PENDING)
        self.assertEqual(row.upi_vpa, 'testuser@upi')
        self.assertEqual(self.profile.bank_status, KycProfile.VerificationStatus.PENDING)
        self.assertEqual(self.profile.upi_status, KycProfile.VerificationStatus.PENDING)
        self.assertEqual(self.profile.bank_verification_method, 'manual_review')
        self.assertEqual(row.review_due_at.date(), (row.submitted_at + timedelta(hours=24)).date())

    def test_staff_can_approve_bank_and_non_staff_cannot(self):
        row = self._submit_payment_review()
        self.client.force_authenticate(self.user)
        forbidden = self.client.post(f'/api/v1/admin-panel/kyc/bank/{row.id}/approve/', {}, format='json')
        self.assertEqual(forbidden.status_code, 403)

        self.client.force_authenticate(self.admin)
        approved = self.client.post(
            f'/api/v1/admin-panel/kyc/bank/{row.id}/approve/',
            {'note': 'Matched cancelled cheque and bank statement.'},
            format='json',
        )
        self.assertEqual(approved.status_code, 200, approved.data)
        row.refresh_from_db()
        self.profile.refresh_from_db()
        account = BankAccount.objects.get(user=self.user)
        self.assertEqual(row.status, BankVerificationRequest.Status.APPROVED)
        self.assertEqual(self.profile.bank_status, KycProfile.VerificationStatus.VERIFIED)
        self.assertEqual(self.profile.upi_status, KycProfile.VerificationStatus.VERIFIED)
        self.assertTrue(account.is_verified)
        self.assertEqual(account.verification_provider, 'manual_admin')

    def test_admin_login_rejects_regular_user(self):
        self.user.set_password('User-Password-123!')
        self.user.save(update_fields=['password'])
        response = self.client.post(
            '/api/v1/admin-panel/auth/login/',
            {'phone': self.user.phone, 'password': 'User-Password-123!'},
            format='json',
        )
        self.assertEqual(response.status_code, 401)

    def test_admin_login_accepts_staff_password(self):
        response = self.client.post(
            '/api/v1/admin-panel/auth/login/',
            {'phone': self.admin.phone, 'password': 'Strong-Test-Password-123!'},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['access'])


@override_settings(ADMIN_PANEL_DEV_NO_AUTH=False)
class ApplicationErrorCenterTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(
            phone='9111111111',
            name='Error Admin',
            is_staff=True,
            is_superuser=True,
        )
        self.user = User.objects.create_user(phone='9222222222', name='Affected User')

    def test_client_report_is_redacted_and_deduplicated(self):
        payload = {
            'message': 'Failure for 9222222222 and ABCDE1234F',
            'exceptionType': 'ApiException',
            'location': '/wallet/deposit?token=secret',
            'context': {'password': 'secret', 'email': 'person@example.com'},
        }
        first = self.client.post('/api/v1/client-errors/', payload, format='json')
        second = self.client.post('/api/v1/client-errors/', payload, format='json')
        self.assertEqual(first.status_code, 202, first.data)
        self.assertEqual(second.status_code, 202, second.data)
        row = ApplicationErrorEvent.objects.get()
        self.assertEqual(row.occurrence_count, 2)
        self.assertNotIn('9222222222', row.message)
        self.assertNotIn('ABCDE1234F', row.message)
        self.assertEqual(row.context['password'], '[redacted]')
        self.assertEqual(row.location, '/wallet/deposit')

    def test_error_list_requires_staff_and_can_resolve(self):
        row = record_error_event(
            source='backend',
            message='Database unavailable',
            exception_type='OperationalError',
            location='/api/v1/wallet/',
        )
        self.client.force_authenticate(self.user)
        forbidden = self.client.get('/api/v1/admin-panel/errors/')
        self.assertEqual(forbidden.status_code, 403)

        self.client.force_authenticate(self.admin)
        response = self.client.get('/api/v1/admin-panel/errors/?status=open')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['results'][0]['id'], str(row.id))
        resolved = self.client.post(
            f'/api/v1/admin-panel/errors/{row.id}/resolve/',
            {},
            format='json',
        )
        self.assertEqual(resolved.status_code, 200, resolved.data)
        row.refresh_from_db()
        self.assertEqual(row.status, ApplicationErrorEvent.Status.RESOLVED)

    def test_retention_command_deletes_old_events(self):
        row = record_error_event(source='backend', message='Old error', location='/old/')
        ApplicationErrorEvent.objects.filter(pk=row.pk).update(
            last_seen_at=timezone.now() - timedelta(days=91)
        )
        call_command('purge_error_events', days=90)
        self.assertFalse(ApplicationErrorEvent.objects.filter(pk=row.pk).exists())

    def test_rds_slot_errors_are_not_written_to_the_error_table(self):
        row = record_error_event(
            source='backend',
            message=(
                'connection to server at "database-2.example.rds.amazonaws.com" '
                'failed: FATAL: remaining connection slots are reserved for '
                'roles with privileges of the "rds_reserved" role'
            ),
            exception_type='OperationalError',
            location='/api/v1/auth/send-otp/',
        )
        self.assertIsNone(row)
        self.assertEqual(ApplicationErrorEvent.objects.count(), 0)

    def test_503_responses_are_not_persisted_as_application_errors(self):
        from django.http import HttpResponse
        from django.test import RequestFactory

        from core.middleware import RequestLogMiddleware

        middleware = RequestLogMiddleware(lambda request: HttpResponse(status=503))
        request = RequestFactory().post('/api/v1/auth/send-otp/')
        middleware(request)
        self.assertEqual(ApplicationErrorEvent.objects.count(), 0)


@override_settings(ADMIN_PANEL_DEV_NO_AUTH=False)
class AdminBroadcastTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(phone='9333333333', name='Broadcast Admin', is_staff=True)
        self.admin.set_password('Strong-Test-Password-123!')
        self.admin.save(update_fields=['password'])
        self.user_one = User.objects.create_user(phone='9444444444', name='User One')
        self.user_two = User.objects.create_user(phone='9555555555', name='User Two')

    def test_staff_can_broadcast_to_customers(self):
        self.client.force_authenticate(self.admin)
        response = self.client.post(
            '/api/v1/admin-panel/broadcasts/',
            {
                'title': 'Market holiday',
                'message': 'Markets are closed tomorrow.',
                'category': 'announcement',
                'audience': 'customers',
            },
            format='json',
        )
        self.assertEqual(response.status_code, 201, response.data)
        broadcast = AdminBroadcast.objects.get()
        self.assertEqual(broadcast.recipient_count, 2)
        self.assertEqual(Notification.objects.filter(type='announcement').count(), 2)
        self.assertFalse(Notification.objects.filter(user=self.admin).exists())

    def test_support_reply_creates_user_notification_with_ticket_reference(self):
        ticket = SupportTicket.objects.create(
            user=self.user_one,
            subject='Need help',
            message='Please assist',
        )
        self.client.force_authenticate(self.admin)
        response = self.client.post(
            f'/api/v1/admin-panel/support/tickets/{ticket.id}/reply/',
            {'message': 'We are looking into this.'},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        notif = Notification.objects.get(user=self.user_one, type='support')
        self.assertEqual(notif.reference_id, str(ticket.id))
        self.assertIn('We are looking into this.', notif.message)


@override_settings(ADMIN_PANEL_DEV_NO_AUTH=False)
class AdminPanelFnoReviewTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(phone='9000000101', name='Admin', is_staff=True)
        self.admin.set_password('Strong-Test-Password-123!')
        self.admin.save(update_fields=['password'])
        self.user = User.objects.create_user(phone='9000000102', name='Trader User')

    def _submit_fno_document(self):
        from django.core.files.uploadedfile import SimpleUploadedFile

        self.client.force_authenticate(self.user)
        document = SimpleUploadedFile(
            'bank_statement.jpg',
            b'fake-image-content',
            content_type='image/jpeg',
        )
        response = self.client.post(
            '/api/v1/fno/submit/',
            {'proof_type': 'bank_statement', 'document': document},
            format='multipart',
        )
        self.assertEqual(response.status_code, 201, response.data)
        from kyc.models import FnoEligibilityRequest

        return FnoEligibilityRequest.objects.get(user=self.user)

    def test_staff_can_approve_fno_request_from_admin_panel(self):
        row = self._submit_fno_document()
        self.assertEqual(row.status, 'PENDING')

        self.client.force_authenticate(self.user)
        forbidden = self.client.post(f'/api/v1/admin-panel/kyc/fno/{row.id}/approve/', {}, format='json')
        self.assertEqual(forbidden.status_code, 403)

        self.client.force_authenticate(self.admin)
        approved = self.client.post(f'/api/v1/admin-panel/kyc/fno/{row.id}/approve/', {}, format='json')
        self.assertEqual(approved.status_code, 200, approved.data)

        row.refresh_from_db()
        self.user.refresh_from_db()
        self.assertEqual(row.status, 'APPROVED')
        self.assertEqual(self.user.fno_status, User.FnoStatus.VERIFIED)

    def test_kyc_overview_includes_fno_queue(self):
        row = self._submit_fno_document()
        self.client.force_authenticate(self.admin)
        response = self.client.get('/api/v1/admin-panel/kyc/overview/')
        self.assertEqual(response.status_code, 200, response.data)
        self.assertGreaterEqual(response.data['summary']['fnoPending'], 1)
        ids = [item['id'] for item in response.data['fnoRequests']]
        self.assertIn(str(row.id), ids)
        self.assertTrue(response.data['fnoRequests'][0]['document_url'])


@override_settings(ADMIN_PANEL_DEV_NO_AUTH=False, BACKEND_PUBLIC_URL='http://127.0.0.1:8000')
class AdminPanelKycDocumentTests(APITestCase):
    def setUp(self):
        self.admin = User.objects.create_user(phone='9000000201', name='Admin', is_staff=True)
        self.user = User.objects.create_user(phone='9000000202', name='Doc User')
        self.profile = KycProfile.objects.create(user=self.user, mobile_verified=True)

    def test_profile_row_includes_selfie_document_url(self):
        from django.core.files.uploadedfile import SimpleUploadedFile

        self.profile.selfie_image = SimpleUploadedFile(
            'selfie.jpg',
            b'fake-selfie',
            content_type='image/jpeg',
        )
        self.profile.selfie_status = KycProfile.SelfieStatus.COMPLETED
        self.profile.save()

        self.client.force_authenticate(self.admin)
        response = self.client.get('/api/v1/admin-panel/kyc/overview/')
        self.assertEqual(response.status_code, 200, response.data)
        profile_row = next(
            row for row in response.data['profiles'] if row['phone'] == self.user.phone
        )
        self.assertTrue(profile_row['hasDocuments'])
        self.assertTrue(profile_row['selfieUrl'].startswith('http://127.0.0.1:8000/media/'))
        self.assertGreaterEqual(len(profile_row['documents']), 1)
