"""Admin panel notification feed — sync operational alerts and user inbox."""

from django.utils import timezone

from engagement.models import SupportTicket
from finance.models import PaymentOrder
from kyc.models import BankVerificationRequest, KYCRequest
from payments.models import PayoutRecord

from .models import AdminNotification, ApplicationErrorEvent


def _upsert(kind, *, reference_id, title, message, action_tab=''):
    AdminNotification.objects.update_or_create(
        kind=kind,
        reference_id=reference_id,
        defaults={
            'title': title[:200],
            'message': message[:500],
            'action_tab': action_tab,
        },
    )


def sync_admin_notifications():
    """Ensure inbox reflects current open operational work."""
    for ticket in SupportTicket.objects.exclude(status=SupportTicket.Status.RESOLVED).select_related('user'):
        user_label = ticket.user.name or ticket.user.phone
        _upsert(
            AdminNotification.Kind.SUPPORT_TICKET,
            reference_id=str(ticket.id),
            title=f'Support: {ticket.subject[:120]}',
            message=f'{user_label} — {ticket.get_status_display()}',
            action_tab='support',
        )

    for row in KYCRequest.objects.filter(status=KYCRequest.Status.PENDING).select_related('user')[:50]:
        _upsert(
            AdminNotification.Kind.KYC_REVIEW,
            reference_id=f'pan-{row.id}',
            title='PAN review pending',
            message=f'{row.user.phone} submitted PAN documents.',
            action_tab='kyc',
        )

    for row in BankVerificationRequest.objects.filter(
        status=BankVerificationRequest.Status.PENDING
    ).select_related('user')[:50]:
        _upsert(
            AdminNotification.Kind.KYC_REVIEW,
            reference_id=f'bank-{row.id}',
            title='Bank/UPI review pending',
            message=f'{row.user.phone} awaits manual bank review.',
            action_tab='kyc',
        )

    for row in PaymentOrder.objects.filter(status=PaymentOrder.Status.FAILED).order_by('-created_at')[:30]:
        _upsert(
            AdminNotification.Kind.PAYMENT_FAILED,
            reference_id=str(row.id),
            title='Payment failed',
            message=f'{row.user.phone} — ₹{row.amount}',
            action_tab='money',
        )

    for row in PayoutRecord.objects.filter(status=PayoutRecord.Status.FAILED).order_by('-created_at')[:30]:
        _upsert(
            AdminNotification.Kind.PAYOUT_FAILED,
            reference_id=str(row.id),
            title='Payout failed',
            message=f'{row.user.phone} — ₹{row.amount}',
            action_tab='money',
        )

    for row in ApplicationErrorEvent.objects.filter(
        status=ApplicationErrorEvent.Status.OPEN,
        severity=ApplicationErrorEvent.Severity.CRITICAL,
    ).order_by('-last_seen_at')[:30]:
        _upsert(
            AdminNotification.Kind.CRITICAL_ERROR,
            reference_id=str(row.id),
            title='Critical application error',
            message=row.message[:480],
            action_tab='errors',
        )

    # Drop stale support notifications for resolved tickets.
    resolved_ids = {
        str(value)
        for value in SupportTicket.objects.filter(status=SupportTicket.Status.RESOLVED).values_list('id', flat=True)
    }
    if resolved_ids:
        AdminNotification.objects.filter(
            kind=AdminNotification.Kind.SUPPORT_TICKET,
            reference_id__in=resolved_ids,
            is_read=False,
        ).update(is_read=True, read_at=timezone.now())


def serialize_notification(row: AdminNotification) -> dict:
    return {
        'id': str(row.id),
        'kind': row.kind,
        'title': row.title,
        'message': row.message,
        'referenceId': row.reference_id,
        'actionTab': row.action_tab,
        'isRead': row.is_read,
        'createdAt': row.created_at.isoformat(),
    }


def notification_summary() -> dict:
    sync_admin_notifications()
    unread = AdminNotification.objects.filter(is_read=False).count()
    rows = AdminNotification.objects.all()[:80]
    return {
        'unreadCount': unread,
        'results': [serialize_notification(row) for row in rows],
    }
