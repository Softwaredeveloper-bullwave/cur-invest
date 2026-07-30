"""Manual bank + UPI review workflow used by the app and React admin panel."""

from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from accounts.models import BankAccount
from engagement.models import Notification

from .masking import mask_account_number, mask_upi_vpa
from .models import BankVerificationRequest, KycProfile, VerificationAuditLog


class ManualBankReviewError(Exception):
    pass


def _pending_review(user):
    return (
        BankVerificationRequest.objects.filter(user=user, status=BankVerificationRequest.Status.PENDING)
        .order_by('-submitted_at')
        .first()
    )


def serialize_bank_request(row: BankVerificationRequest, *, reveal_account: bool = False) -> dict:
    return {
        'id': str(row.id),
        'userId': str(row.user_id),
        'userPhone': row.user.phone,
        'userName': row.user.name,
        'accountHolderName': row.account_holder_name,
        'accountNumber': row.account_number if reveal_account else mask_account_number(row.account_number),
        'accountNumberMasked': mask_account_number(row.account_number),
        'ifsc': row.ifsc,
        'bankName': row.bank_name,
        'bankBranch': row.bank_branch,
        'upiVpa': row.upi_vpa,
        'upiVpaMasked': mask_upi_vpa(row.upi_vpa) if row.upi_vpa else '',
        'upiMobile': row.upi_mobile,
        'status': row.status,
        'reviewNote': row.review_note,
        'submittedAt': row.submitted_at.isoformat(),
        'reviewDueAt': row.review_due_at.isoformat(),
        'reviewedAt': row.reviewed_at.isoformat() if row.reviewed_at else None,
        'reviewedBy': row.reviewed_by.phone if row.reviewed_by else '',
    }


@transaction.atomic
def save_bank_draft(
    user,
    *,
    account_holder_name: str,
    account_number: str,
    ifsc: str,
    bank_name: str = '',
    bank_branch: str = '',
) -> KycProfile:
    """Store bank details locally before the user completes the UPI step."""
    pending = _pending_review(user)
    if pending:
        raise ManualBankReviewError(
            'Your bank and UPI details are already under review. Please wait for admin approval.'
        )

    profile, _ = KycProfile.objects.select_for_update().get_or_create(user=user)
    profile.account_holder_name = account_holder_name[:120]
    profile.bank_account_number = account_number
    profile.bank_ifsc = ifsc
    profile.bank_name = bank_name[:120]
    profile.bank_branch = bank_branch[:120]
    profile.bank_status = KycProfile.VerificationStatus.PENDING
    profile.bank_reference_id = ''
    profile.bank_verification_method = 'manual_review'
    profile.bank_failure_reason = ''
    profile.bank_verified_at = None
    profile.save(
        update_fields=[
            'account_holder_name',
            'bank_account_number',
            'bank_ifsc',
            'bank_name',
            'bank_branch',
            'bank_status',
            'bank_reference_id',
            'bank_verification_method',
            'bank_failure_reason',
            'bank_verified_at',
            'updated_at',
        ]
    )
    VerificationAuditLog.objects.create(
        user=user,
        step=VerificationAuditLog.Step.BANK,
        status=VerificationAuditLog.Status.STARTED,
        message='Bank details saved — continue to UPI verification.',
        request_meta={'account': mask_account_number(account_number), 'ifsc': ifsc},
    )
    return profile


@transaction.atomic
def submit_payment_review(
    user,
    *,
    upi_vpa: str,
    upi_mobile: str = '',
) -> BankVerificationRequest:
    """Create a combined bank + UPI review ticket for admin approval."""
    profile = KycProfile.objects.select_for_update().filter(user=user).first()
    if not profile or not profile.bank_account_number or not profile.bank_ifsc:
        raise ManualBankReviewError('Enter and save your bank details before submitting UPI.')

    upi_vpa = upi_vpa.strip().lower()
    if not upi_vpa:
        raise ManualBankReviewError('Enter your UPI ID.')

    pending = (
        BankVerificationRequest.objects.select_for_update()
        .filter(user=user, status=BankVerificationRequest.Status.PENDING)
        .first()
    )
    if (
        pending
        and pending.account_number == profile.bank_account_number
        and pending.ifsc == profile.bank_ifsc
        and pending.upi_vpa == upi_vpa
    ):
        return pending
    if pending:
        pending.status = BankVerificationRequest.Status.SUPERSEDED
        pending.review_note = 'Superseded by a newer bank + UPI submission.'
        pending.save(update_fields=['status', 'review_note', 'updated_at'])

    due_at = timezone.now() + timedelta(hours=24)
    row = BankVerificationRequest.objects.create(
        user=user,
        account_holder_name=profile.account_holder_name,
        account_number=profile.bank_account_number,
        ifsc=profile.bank_ifsc,
        bank_name=profile.bank_name,
        bank_branch=profile.bank_branch,
        upi_vpa=upi_vpa,
        upi_mobile=(upi_mobile or '')[:15],
        review_due_at=due_at,
    )

    profile.bank_status = KycProfile.VerificationStatus.PENDING
    profile.bank_reference_id = f'manual:{row.id}'
    profile.bank_verification_method = 'manual_review'
    profile.bank_failure_reason = ''
    profile.bank_verified_at = None
    profile.upi_vpa = upi_vpa
    profile.upi_mobile = (upi_mobile or '')[:15]
    profile.upi_status = KycProfile.VerificationStatus.PENDING
    profile.upi_reference_id = f'manual:{row.id}'
    profile.upi_failure_reason = ''
    profile.upi_verified_at = None
    profile.save(
        update_fields=[
            'bank_status',
            'bank_reference_id',
            'bank_verification_method',
            'bank_failure_reason',
            'bank_verified_at',
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
        step=VerificationAuditLog.Step.BANK,
        status=VerificationAuditLog.Status.STARTED,
        message='Bank + UPI submitted for manual admin review within 24 hours.',
        request_meta={
            'account': mask_account_number(row.account_number),
            'ifsc': row.ifsc,
            'vpa': mask_upi_vpa(upi_vpa),
            'review_id': str(row.id),
        },
    )
    VerificationAuditLog.objects.create(
        user=user,
        step=VerificationAuditLog.Step.UPI,
        status=VerificationAuditLog.Status.STARTED,
        message='Bank + UPI submitted for manual admin review within 24 hours.',
        request_meta={'vpa': mask_upi_vpa(upi_vpa), 'review_id': str(row.id)},
    )
    Notification.objects.create(
        user=user,
        title='Bank & UPI under review',
        message='Your bank account and UPI ID were submitted. Verification may take up to 24 hours.',
        type='kyc',
    )
    return row


@transaction.atomic
def approve_bank_review(row: BankVerificationRequest, admin_user, *, note: str = '') -> BankVerificationRequest:
    row = BankVerificationRequest.objects.select_for_update().select_related('user').get(pk=row.pk)
    if row.status != BankVerificationRequest.Status.PENDING:
        raise ManualBankReviewError('Only pending payment requests can be approved.')

    now = timezone.now()
    row.status = BankVerificationRequest.Status.APPROVED
    row.review_note = (note or 'Verified manually by admin.')[:500]
    row.reviewed_by = admin_user
    row.reviewed_at = now
    row.save(update_fields=['status', 'review_note', 'reviewed_by', 'reviewed_at', 'updated_at'])

    profile, _ = KycProfile.objects.select_for_update().get_or_create(user=row.user)
    profile.account_holder_name = row.account_holder_name
    profile.bank_account_number = row.account_number
    profile.bank_ifsc = row.ifsc
    profile.bank_name = row.bank_name
    profile.bank_branch = row.bank_branch
    profile.name_at_bank = row.account_holder_name
    profile.bank_status = KycProfile.VerificationStatus.VERIFIED
    profile.bank_reference_id = f'manual:{row.id}'
    profile.bank_verification_method = 'manual_review'
    profile.bank_failure_reason = ''
    profile.bank_verified_at = now
    if row.upi_vpa:
        profile.upi_vpa = row.upi_vpa
        profile.upi_mobile = row.upi_mobile
        profile.upi_name = row.account_holder_name[:120]
        profile.upi_status = KycProfile.VerificationStatus.VERIFIED
        profile.upi_reference_id = f'manual:{row.id}'
        profile.upi_failure_reason = ''
        profile.upi_verified_at = now
    profile.save()

    account, _ = BankAccount.objects.get_or_create(
        user=row.user,
        defaults={
            'account_holder_name': row.account_holder_name,
            'bank_name': row.bank_name,
            'account_number': row.account_number,
            'ifsc': row.ifsc,
            'pan_number': profile.pan_number,
        },
    )
    account.account_holder_name = row.account_holder_name
    account.bank_name = row.bank_name
    account.account_number = row.account_number
    account.ifsc = row.ifsc
    account.pan_number = profile.pan_number
    account.is_verified = True
    account.verification_provider = 'manual_admin'
    account.verification_reference_id = str(row.id)
    account.verification_status = 'verified'
    account.verification_message = row.review_note[:280]
    account.name_at_bank = row.account_holder_name
    account.verified_at = now
    account.save()

    from .service import _sync_user_name_from_kyc, _update_overall_status

    _sync_user_name_from_kyc(row.user, profile)
    _update_overall_status(profile)
    VerificationAuditLog.objects.create(
        user=row.user,
        step=VerificationAuditLog.Step.BANK,
        status=VerificationAuditLog.Status.SUCCESS,
        message=row.review_note,
        response_meta={'provider': 'manual_admin', 'review_id': str(row.id), 'reviewer': str(admin_user.id)},
    )
    if row.upi_vpa:
        VerificationAuditLog.objects.create(
            user=row.user,
            step=VerificationAuditLog.Step.UPI,
            status=VerificationAuditLog.Status.SUCCESS,
            message=row.review_note,
            response_meta={'provider': 'manual_admin', 'review_id': str(row.id), 'reviewer': str(admin_user.id)},
        )
    Notification.objects.create(
        user=row.user,
        title='Bank & UPI verified',
        message='Your bank account and UPI ID have been manually verified.',
        type='kyc',
    )
    return row


@transaction.atomic
def reject_bank_review(row: BankVerificationRequest, admin_user, *, reason: str) -> BankVerificationRequest:
    row = BankVerificationRequest.objects.select_for_update().select_related('user').get(pk=row.pk)
    if row.status != BankVerificationRequest.Status.PENDING:
        raise ManualBankReviewError('Only pending payment requests can be rejected.')
    reason = (reason or '').strip()
    if len(reason) < 3:
        raise ManualBankReviewError('Enter a clear rejection reason.')

    now = timezone.now()
    row.status = BankVerificationRequest.Status.REJECTED
    row.review_note = reason[:500]
    row.reviewed_by = admin_user
    row.reviewed_at = now
    row.save(update_fields=['status', 'review_note', 'reviewed_by', 'reviewed_at', 'updated_at'])

    profile, _ = KycProfile.objects.select_for_update().get_or_create(user=row.user)
    manual_ref = f'manual:{row.id}'
    if profile.bank_reference_id == manual_ref:
        profile.bank_status = KycProfile.VerificationStatus.FAILED
        profile.bank_failure_reason = reason[:280]
        profile.bank_verified_at = None
    if profile.upi_reference_id == manual_ref:
        profile.upi_status = KycProfile.VerificationStatus.FAILED
        profile.upi_failure_reason = reason[:280]
        profile.upi_verified_at = None
    profile.save()
    from .service import _update_overall_status

    _update_overall_status(profile)

    BankAccount.objects.filter(user=row.user).update(
        is_verified=False,
        verification_status='failed',
        verification_message=reason[:280],
        verified_at=None,
    )
    VerificationAuditLog.objects.create(
        user=row.user,
        step=VerificationAuditLog.Step.BANK,
        status=VerificationAuditLog.Status.FAILED,
        message=reason[:500],
        response_meta={'provider': 'manual_admin', 'review_id': str(row.id), 'reviewer': str(admin_user.id)},
    )
    if row.upi_vpa:
        VerificationAuditLog.objects.create(
            user=row.user,
            step=VerificationAuditLog.Step.UPI,
            status=VerificationAuditLog.Status.FAILED,
            message=reason[:500],
            response_meta={'provider': 'manual_admin', 'review_id': str(row.id), 'reviewer': str(admin_user.id)},
        )
    Notification.objects.create(
        user=row.user,
        title='Verification needs attention',
        message=reason[:280],
        type='kyc',
    )
    return row
