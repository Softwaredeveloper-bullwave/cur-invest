"""Selfie capture upload and manual admin review."""

from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification

from .models import KycProfile, VerificationAuditLog
from .service import (
    _bank_ready_for_identity_steps,
    _bank_really_verified,
    _update_overall_status,
    get_or_create_profile,
    upi_step_required,
    _upi_really_verified,
)


SELFIE_REVIEW_HOURS = 24
MAX_SELFIE_BYTES = 2 * 1024 * 1024  # 2 MB after client compression


class SelfieError(Exception):
    pass


def _selfie_really_verified(profile: KycProfile) -> bool:
    return profile.selfie_status == KycProfile.SelfieStatus.VERIFIED


def serialize_selfie_review(profile: KycProfile, request) -> dict:
    selfie_url = ''
    if profile.selfie_image:
        selfie_url = request.build_absolute_uri(profile.selfie_image.url)
    return {
        'userId': str(profile.user_id),
        'userPhone': profile.user.phone,
        'userName': profile.user.name,
        'userEmail': profile.user.email,
        'selfieUrl': selfie_url,
        'selfieStatus': profile.selfie_status,
        'uploadedAt': profile.selfie_uploaded_at.isoformat() if profile.selfie_uploaded_at else None,
        'reviewDueAt': profile.selfie_review_due_at.isoformat() if profile.selfie_review_due_at else None,
        'reviewNote': profile.selfie_review_note,
        'reviewedAt': profile.selfie_reviewed_at.isoformat() if profile.selfie_reviewed_at else None,
        'reviewedBy': profile.selfie_reviewed_by.phone if profile.selfie_reviewed_by else '',
        'panName': profile.pan_name,
        'bankStatus': profile.bank_status,
    }


def _assert_selfie_prerequisites(profile: KycProfile) -> None:
    if not _bank_ready_for_identity_steps(profile):
        raise SelfieError(
            'Complete bank verification before capturing a selfie. '
            'Go back to Bank Verification if live verification is still pending.'
        )
    from .identity_review_service import manual_upi_enabled

    if manual_upi_enabled():
        return
    if upi_step_required() and not _upi_really_verified(profile):
        raise SelfieError('Complete UPI verification before capturing a selfie.')


@transaction.atomic
def upload_selfie(user, image_file) -> KycProfile:
    profile = get_or_create_profile(user)
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    _assert_selfie_prerequisites(profile)

    if profile.selfie_status == KycProfile.SelfieStatus.COMPLETED:
        raise SelfieError('Selfie already submitted and under manual review.')
    if profile.selfie_status == KycProfile.SelfieStatus.VERIFIED:
        raise SelfieError('Selfie already verified.')

    if not image_file:
        raise SelfieError('Selfie image is required.')
    if image_file.size > MAX_SELFIE_BYTES:
        raise SelfieError('Selfie image is too large. Please retake with lower quality.')

    content_type = getattr(image_file, 'content_type', '') or ''
    if content_type and not content_type.startswith('image/'):
        raise SelfieError('Only image files are allowed for selfie upload.')

    if profile.selfie_image:
        profile.selfie_image.delete(save=False)

    profile.selfie_image = image_file
    profile.selfie_status = KycProfile.SelfieStatus.COMPLETED
    now = timezone.now()
    profile.selfie_uploaded_at = now
    profile.selfie_review_due_at = now + timedelta(hours=SELFIE_REVIEW_HOURS)
    profile.selfie_review_note = ''
    profile.selfie_reviewed_at = None
    profile.selfie_reviewed_by = None
    profile.save(
        update_fields=[
            'selfie_image',
            'selfie_status',
            'selfie_uploaded_at',
            'selfie_review_due_at',
            'selfie_review_note',
            'selfie_reviewed_at',
            'selfie_reviewed_by',
            'updated_at',
        ]
    )

    VerificationAuditLog.objects.create(
        user=user,
        step=VerificationAuditLog.Step.SELFIE,
        status=VerificationAuditLog.Status.SUCCESS,
        message='Selfie uploaded — awaiting manual review (up to 24 hours).',
    )
    _update_overall_status(profile)
    return profile


@transaction.atomic
def approve_selfie(profile: KycProfile, reviewer, note: str = '') -> KycProfile:
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    if profile.selfie_status != KycProfile.SelfieStatus.COMPLETED:
        raise SelfieError('No pending selfie to approve.')
    if not profile.selfie_image:
        raise SelfieError('Selfie image missing on profile.')

    profile.selfie_status = KycProfile.SelfieStatus.VERIFIED
    profile.selfie_review_note = (note or 'Selfie verified by admin.')[:500]
    profile.selfie_reviewed_at = timezone.now()
    profile.selfie_reviewed_by = reviewer
    profile.save(
        update_fields=[
            'selfie_status',
            'selfie_review_note',
            'selfie_reviewed_at',
            'selfie_reviewed_by',
            'updated_at',
        ]
    )

    VerificationAuditLog.objects.create(
        user=profile.user,
        step=VerificationAuditLog.Step.SELFIE,
        status=VerificationAuditLog.Status.SUCCESS,
        message='Selfie manually approved by admin.',
    )
    Notification.objects.create(
        user=profile.user,
        title='Selfie verified',
        message='Your selfie has been verified. Continue with the remaining KYC steps.',
        type='kyc',
    )
    _update_overall_status(profile)
    return profile


@transaction.atomic
def reject_selfie(profile: KycProfile, reviewer, reason: str = '') -> KycProfile:
    profile = KycProfile.objects.select_for_update().get(pk=profile.pk)
    if profile.selfie_status != KycProfile.SelfieStatus.COMPLETED:
        raise SelfieError('No pending selfie to reject.')

    profile.selfie_status = KycProfile.SelfieStatus.REJECTED
    profile.selfie_review_note = (reason or 'Selfie could not be verified. Please retake.')[:500]
    profile.selfie_reviewed_at = timezone.now()
    profile.selfie_reviewed_by = reviewer
    profile.save(
        update_fields=[
            'selfie_status',
            'selfie_review_note',
            'selfie_reviewed_at',
            'selfie_reviewed_by',
            'updated_at',
        ]
    )

    VerificationAuditLog.objects.create(
        user=profile.user,
        step=VerificationAuditLog.Step.SELFIE,
        status=VerificationAuditLog.Status.FAILED,
        message=profile.selfie_review_note,
    )
    Notification.objects.create(
        user=profile.user,
        title='Selfie verification failed',
        message=profile.selfie_review_note,
        type='kyc',
    )
    _update_overall_status(profile)
    return profile
