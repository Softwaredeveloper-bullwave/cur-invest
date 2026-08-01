"""Manual UPI + selfie identity review after automated bank verification."""

import uuid

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .masking import mask_upi_vpa
from .models import KycProfile, VerificationAuditLog
from .service import (
    _bank_ready_for_identity_steps,
    _bank_really_verified,
    _selfie_really_verified,
    _update_overall_status,
    get_or_create_profile,
)


class IdentityReviewError(Exception):
    pass


def manual_upi_enabled() -> bool:
    return bool(getattr(settings, 'KYC_UPI_MANUAL', False))


def manual_final_approval_required() -> bool:
    return bool(getattr(settings, 'KYC_MANUAL_FINAL_APPROVAL', True))


def identity_review_pending(profile: KycProfile) -> bool:
    upi_waiting = (
        bool(profile.upi_vpa)
        and profile.upi_status == KycProfile.VerificationStatus.PENDING
        and str(profile.upi_reference_id or '').startswith('manual')
    )
    selfie_waiting = profile.selfie_status == KycProfile.SelfieStatus.COMPLETED
    return upi_waiting or selfie_waiting


def serialize_identity_review(profile: KycProfile, request) -> dict:
    selfie_url = ''
    if profile.selfie_image:
        selfie_url = request.build_absolute_uri(profile.selfie_image.url)
    return {
        'userId': str(profile.user_id),
        'userPhone': profile.user.phone,
        'userName': profile.user.name,
        'userEmail': profile.user.email,
        'panName': profile.pan_name,
        'bankStatus': profile.bank_status,
        'upiVpa': profile.upi_vpa,
        'upiVpaMasked': mask_upi_vpa(profile.upi_vpa) if profile.upi_vpa else '',
        'upiStatus': profile.upi_status,
        'selfieStatus': profile.selfie_status,
        'selfieUrl': selfie_url,
        'selfieUploadedAt': profile.selfie_uploaded_at.isoformat() if profile.selfie_uploaded_at else None,
        'overallStatus': profile.overall_status,
        'readyForFinalApproval': ready_for_final_kyc_approval(profile),
    }


def ready_for_final_kyc_approval(profile: KycProfile) -> bool:
    if not manual_final_approval_required():
        return False
    if profile.final_kyc_approved_at:
        return False
    if not _bank_really_verified(profile):
        return False
    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        return False
    if profile.aadhaar_status != KycProfile.VerificationStatus.VERIFIED:
        return False
    if manual_upi_enabled() and profile.upi_status != KycProfile.VerificationStatus.VERIFIED:
        return False
    if not _selfie_really_verified(profile):
        return False
    return True


@transaction.atomic
def submit_manual_upi(user, *, upi_vpa: str, upi_mobile: str = '') -> KycProfile:
    """Store UPI for manual admin review after Eko bank verification."""
    profile = get_or_create_profile(user)
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    if not _bank_ready_for_identity_steps(profile):
        raise IdentityReviewError(
            'Complete bank verification before submitting UPI. '
            'If you only saved bank details, go back and complete live bank verification.'
        )
    if profile.upi_status == KycProfile.VerificationStatus.VERIFIED:
        raise IdentityReviewError('UPI is already verified.')

    upi_vpa = upi_vpa.strip().lower()
    if not upi_vpa or '@' not in upi_vpa:
        raise IdentityReviewError('Enter a valid UPI ID (example@upi).')

    ref = f'manual:upi:{uuid.uuid4().hex[:16]}'
    profile.upi_vpa = upi_vpa[:120]
    profile.upi_mobile = (upi_mobile or '')[:15]
    profile.upi_status = KycProfile.VerificationStatus.PENDING
    profile.upi_reference_id = ref
    profile.upi_failure_reason = ''
    profile.upi_verified_at = None
    profile.save(
        update_fields=[
            'upi_vpa',
            'upi_mobile',
            'upi_status',
            'upi_reference_id',
            'upi_failure_reason',
            'upi_verified_at',
            'updated_at',
        ]
    )
    VerificationAuditLog.objects.create(
        user=user,
        step=VerificationAuditLog.Step.UPI,
        status=VerificationAuditLog.Status.STARTED,
        message='UPI submitted for manual admin review.',
        request_meta={'vpa': mask_upi_vpa(upi_vpa), 'reference_id': ref},
    )
    _update_overall_status(profile)
    return profile


@transaction.atomic
def reject_manual_upi(profile: KycProfile, reviewer, reason: str = '') -> KycProfile:
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    if not profile.upi_vpa:
        raise IdentityReviewError('No UPI ID on file.')
    if profile.upi_status == KycProfile.VerificationStatus.VERIFIED:
        raise IdentityReviewError('UPI is already verified.')

    profile.upi_status = KycProfile.VerificationStatus.FAILED
    profile.upi_failure_reason = (reason or 'UPI rejected by admin.')[:280]
    profile.upi_verified_at = None
    profile.save(
        update_fields=[
            'upi_status',
            'upi_failure_reason',
            'upi_verified_at',
            'updated_at',
        ]
    )
    VerificationAuditLog.objects.create(
        user=profile.user,
        step=VerificationAuditLog.Step.UPI,
        status=VerificationAuditLog.Status.FAILED,
        message=profile.upi_failure_reason,
        response_meta={'provider': 'manual_admin', 'reviewer': str(reviewer.id)},
    )
    Notification.objects.create(
        user=profile.user,
        title='UPI verification failed',
        message=profile.upi_failure_reason,
        type='kyc',
    )
    _update_overall_status(profile)
    return profile


@transaction.atomic
def approve_manual_upi(profile: KycProfile, reviewer, note: str = '') -> KycProfile:
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    if not profile.upi_vpa:
        raise IdentityReviewError('No UPI ID on file.')
    if profile.upi_status == KycProfile.VerificationStatus.VERIFIED:
        return profile
    if profile.upi_status != KycProfile.VerificationStatus.PENDING:
        raise IdentityReviewError('UPI is not awaiting review.')

    now = timezone.now()
    profile.upi_status = KycProfile.VerificationStatus.VERIFIED
    profile.upi_name = (profile.pan_name or profile.account_holder_name or profile.user.name)[:120]
    profile.upi_failure_reason = ''
    profile.upi_verified_at = now
    profile.save(
        update_fields=[
            'upi_status',
            'upi_name',
            'upi_failure_reason',
            'upi_verified_at',
            'updated_at',
        ]
    )
    VerificationAuditLog.objects.create(
        user=profile.user,
        step=VerificationAuditLog.Step.UPI,
        status=VerificationAuditLog.Status.SUCCESS,
        message=(note or 'UPI manually approved by admin.')[:280],
        response_meta={'provider': 'manual_admin', 'reviewer': str(reviewer.id)},
    )
    Notification.objects.create(
        user=profile.user,
        title='UPI verified',
        message='Your UPI ID has been verified. We will complete your KYC shortly.',
        type='kyc',
    )
    _update_overall_status(profile)
    return profile


@transaction.atomic
def final_kyc_approve(profile: KycProfile, reviewer, note: str = '') -> KycProfile:
    profile = KycProfile.objects.select_for_update().select_related('user').get(pk=profile.pk)
    if not ready_for_final_kyc_approval(profile):
        raise IdentityReviewError(
            'PAN, Aadhaar, bank, UPI, and selfie must all be verified before final approval.'
        )

    now = timezone.now()
    profile.name_match_result = 'ADMIN_APPROVED'
    profile.name_match_score = 100
    profile.name_match_passed = True
    profile.name_match_checked_at = now
    profile.final_kyc_approved_at = now
    profile.final_kyc_approved_by = reviewer
    profile.save(
        update_fields=[
            'name_match_result',
            'name_match_score',
            'name_match_passed',
            'name_match_checked_at',
            'final_kyc_approved_at',
            'final_kyc_approved_by',
            'updated_at',
        ]
    )
    _update_overall_status(profile)
    VerificationAuditLog.objects.create(
        user=profile.user,
        step=VerificationAuditLog.Step.NAME_MATCH,
        status=VerificationAuditLog.Status.SUCCESS,
        message=(note or 'KYC manually approved by admin.')[:280],
        response_meta={'provider': 'manual_admin', 'reviewer': str(reviewer.id)},
    )
    Notification.objects.create(
        user=profile.user,
        title='KYC complete',
        message='Your account verification is complete. You can now start investing.',
        type='kyc',
    )
    return profile
