import uuid

from django.conf import settings
from django.db import models


class KycProfile(models.Model):
    class VerificationStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        VERIFIED = 'verified', 'Verified'
        FAILED = 'failed', 'Failed'

    class OverallStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        UNDER_REVIEW = 'under_review', 'Under review'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='kyc_profile'
    )
    mobile_verified = models.BooleanField(default=False)

    pan_number = models.CharField(max_length=10, blank=True, default='')
    pan_name = models.CharField(max_length=120, blank=True, default='')
    pan_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    pan_reference_id = models.CharField(max_length=64, blank=True, default='')
    pan_failure_reason = models.CharField(max_length=280, blank=True, default='')
    pan_verified_at = models.DateTimeField(null=True, blank=True)
    pan_dob = models.DateField(null=True, blank=True)

    # Aadhaar OTP eKYC (Eko) — run after PAN, before bank.
    # Full Aadhaar is encrypted only while an OTP flow is pending, then
    # deleted after verification. The last four digits are retained for UI.
    aadhaar_number = models.CharField(max_length=255, blank=True, default='')
    aadhaar_last4 = models.CharField(max_length=4, blank=True, default='')
    aadhaar_name = models.CharField(max_length=120, blank=True, default='')
    aadhaar_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    # Eko's real otp_ref_id/reference_tid tokens are long encoded strings
    # (confirmed in production at 96+ chars, e.g. "HiRXSQ6wAFOV3pilh3evP4A...")
    # — max_length=64 was too small and caused Postgres to raise a hard
    # DataError (surfaced to the app as an unhandled HTTP 500) the moment a
    # real token was saved. Widened to 512 to be safe.
    aadhaar_otp_ref_id = models.CharField(max_length=512, blank=True, default='')
    aadhaar_reference_id = models.CharField(max_length=512, blank=True, default='')
    aadhaar_failure_reason = models.CharField(max_length=280, blank=True, default='')
    aadhaar_otp_sent_at = models.DateTimeField(null=True, blank=True)
    aadhaar_verified_at = models.DateTimeField(null=True, blank=True)
    aadhaar_dob = models.DateField(null=True, blank=True)
    # Eko DigiLocker consent journey (the supported production Aadhaar flow).
    aadhaar_digilocker_url = models.URLField(max_length=1000, blank=True, default='')
    aadhaar_digilocker_client_ref_id = models.CharField(max_length=64, blank=True, default='')
    aadhaar_digilocker_verification_id = models.CharField(max_length=255, blank=True, default='')
    aadhaar_digilocker_state_digest = models.CharField(max_length=64, blank=True, default='')
    aadhaar_digilocker_started_at = models.DateTimeField(null=True, blank=True)
    # Eko requires the mobile number to be onboarded as a DigiKhata "sender"
    # (one-time mobile-verification OTP) before Aadhaar OTP will work at all.
    aadhaar_sender_enrolled = models.BooleanField(default=False)
    aadhaar_sender_otp_ref_id = models.CharField(max_length=512, blank=True, default='')

    account_holder_name = models.CharField(max_length=120, blank=True, default='')
    bank_name = models.CharField(max_length=120, blank=True, default='')
    bank_account_number = models.CharField(max_length=20, blank=True, default='')
    bank_ifsc = models.CharField(max_length=11, blank=True, default='')
    bank_branch = models.CharField(max_length=120, blank=True, default='')
    bank_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    # Widened defensively for the same reason as the Aadhaar fields above —
    # Eko's real reference/tid tokens can be far longer than 64 chars.
    bank_reference_id = models.CharField(max_length=512, blank=True, default='')
    bank_utr = models.CharField(max_length=64, blank=True, default='')
    bank_account_status = models.CharField(max_length=32, blank=True, default='')
    bank_account_status_code = models.CharField(max_length=64, blank=True, default='')
    bank_failure_reason = models.CharField(max_length=280, blank=True, default='')
    bank_verification_method = models.CharField(max_length=20, blank=True, default='')
    bank_verified_at = models.DateTimeField(null=True, blank=True)
    name_at_bank = models.CharField(max_length=120, blank=True, default='')

    upi_vpa = models.CharField(max_length=120, blank=True, default='')
    upi_name = models.CharField(max_length=120, blank=True, default='')
    upi_mobile = models.CharField(max_length=15, blank=True, default='')
    upi_status = models.CharField(
        max_length=20, choices=VerificationStatus.choices, default=VerificationStatus.PENDING
    )
    upi_reference_id = models.CharField(max_length=512, blank=True, default='')
    upi_failure_reason = models.CharField(max_length=280, blank=True, default='')
    upi_name_match_score = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    upi_verified_at = models.DateTimeField(null=True, blank=True)

    name_match_result = models.CharField(max_length=40, blank=True, default='')
    name_match_score = models.DecimalField(max_digits=5, decimal_places=2, default=0)
    name_match_passed = models.BooleanField(default=False)
    name_match_checked_at = models.DateTimeField(null=True, blank=True)

    class SelfieStatus(models.TextChoices):
        PENDING = 'pending', 'Pending'
        COMPLETED = 'completed', 'Completed'
        VERIFIED = 'verified', 'Verified'
        REJECTED = 'rejected', 'Rejected'

    selfie_image = models.ImageField(upload_to='kyc/selfie/%Y/%m/', blank=True, default='')
    selfie_status = models.CharField(
        max_length=20,
        choices=SelfieStatus.choices,
        default=SelfieStatus.PENDING,
    )
    selfie_uploaded_at = models.DateTimeField(null=True, blank=True)
    selfie_review_due_at = models.DateTimeField(null=True, blank=True)
    selfie_review_note = models.CharField(max_length=500, blank=True, default='')
    selfie_reviewed_at = models.DateTimeField(null=True, blank=True)
    selfie_reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='selfie_reviews',
    )

    overall_status = models.CharField(
        max_length=20, choices=OverallStatus.choices, default=OverallStatus.PENDING
    )
    final_kyc_approved_at = models.DateTimeField(null=True, blank=True)
    final_kyc_approved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='final_kyc_approvals',
    )
    verified_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'KYC {self.user.phone}'


class KYCRequest(models.Model):
    """Manual PAN KYC submission — reviewed by admin (no Cashfree)."""

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        APPROVED = 'APPROVED', 'Approved'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='kyc_requests'
    )
    pan_number = models.CharField(max_length=10)
    full_name = models.CharField(max_length=120)
    dob = models.DateField()
    pan_image = models.ImageField(upload_to='kyc/pan/%Y/%m/')
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )
    rejection_reason = models.CharField(max_length=500, blank=True, default='')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='kyc_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', 'created_at'])]

    @property
    def pan_image_url(self) -> str:
        if self.pan_image:
            return self.pan_image.url
        return ''

    def __str__(self):
        return f'KYCRequest {self.pan_number} ({self.status})'


class KYCRequestImage(models.Model):
    """Additional PAN / ID photos attached to a manual KYC request."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    request = models.ForeignKey(
        KYCRequest, on_delete=models.CASCADE, related_name='images'
    )
    image = models.ImageField(upload_to='kyc/pan/%Y/%m/')
    sort_order = models.PositiveSmallIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['sort_order', 'created_at']

    def __str__(self):
        return f'KYC image {self.request_id} #{self.sort_order}'


class BankVerificationRequest(models.Model):
    """Bank + UPI details submitted for staff review within 24 hours."""

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        APPROVED = 'approved', 'Approved'
        REJECTED = 'rejected', 'Rejected'
        SUPERSEDED = 'superseded', 'Superseded'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='bank_verification_requests',
    )
    account_holder_name = models.CharField(max_length=120, blank=True, default='')
    account_number = models.CharField(max_length=20)
    ifsc = models.CharField(max_length=11)
    bank_name = models.CharField(max_length=120, blank=True, default='')
    bank_branch = models.CharField(max_length=120, blank=True, default='')
    upi_vpa = models.CharField(max_length=120, blank=True, default='')
    upi_mobile = models.CharField(max_length=15, blank=True, default='')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    review_note = models.CharField(max_length=500, blank=True, default='')
    submitted_at = models.DateTimeField(auto_now_add=True)
    review_due_at = models.DateTimeField()
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='bank_verification_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-submitted_at']
        indexes = [
            models.Index(
                fields=['status', 'review_due_at'],
                name='kyc_bankver_status_24f079_idx',
            ),
            models.Index(
                fields=['user', 'submitted_at'],
                name='kyc_bankver_user_id_a459f4_idx',
            ),
        ]

    def __str__(self):
        return f'Bank review {self.user.phone} ({self.status})'


class FnoEligibilityRequest(models.Model):
    """F&O eligibility proof — admin review or instant portfolio check."""

    class ProofType(models.TextChoices):
        BANK_STATEMENT = 'bank_statement', '6-Month Bank Statement'
        FORM16 = 'form16', 'FORM 16'
        ITR = 'itr', 'ITR Form'
        PORTFOLIO_HOLDING = 'portfolio_holding', '₹50,000 Portfolio Holding'

    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        APPROVED = 'APPROVED', 'Approved'
        REJECTED = 'REJECTED', 'Rejected'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='fno_requests'
    )
    proof_type = models.CharField(max_length=32, choices=ProofType.choices)
    document = models.FileField(upload_to='fno/proofs/%Y/%m/', blank=True, null=True)
    portfolio_value = models.DecimalField(max_digits=14, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    rejection_reason = models.CharField(max_length=500, blank=True, default='')
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='fno_reviews',
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['status', 'created_at'])]

    def __str__(self):
        return f'FNO {self.proof_type} ({self.status}) — {self.user_id}'


class VerificationAuditLog(models.Model):
    class Step(models.TextChoices):
        PAN = 'pan', 'PAN'
        AADHAAR = 'aadhaar', 'Aadhaar'
        BANK = 'bank', 'Bank'
        UPI = 'upi', 'UPI'
        SELFIE = 'selfie', 'Selfie'
        NAME_MATCH = 'name_match', 'Name Match'

    class Status(models.TextChoices):
        STARTED = 'started', 'Started'
        SUCCESS = 'success', 'Success'
        FAILED = 'failed', 'Failed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='verification_logs'
    )
    step = models.CharField(max_length=20, choices=Step.choices)
    status = models.CharField(max_length=20, choices=Status.choices)
    message = models.CharField(max_length=500, blank=True, default='')
    request_meta = models.JSONField(default=dict, blank=True)
    response_meta = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [models.Index(fields=['user', 'step', 'created_at'])]
