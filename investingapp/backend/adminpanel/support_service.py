"""Admin support desk — ticket threads and user notifications."""

from django.db import transaction
from django.utils import timezone

from engagement.models import Notification, SupportTicket, SupportTicketMessage
from engagement.support_service import create_ticket_for_user  # noqa: F401

from .models import AdminNotification
from .notifications_service import _upsert


def _notify_user(user, *, title, message, notif_type='support', reference_id=''):
    Notification.objects.create(
        user=user,
        title=title[:200],
        message=message,
        type=notif_type,
        reference_id=(reference_id or '')[:80],
    )


def serialize_ticket_message(row: SupportTicketMessage) -> dict:
    author_name = ''
    if row.author_id:
        author_name = row.author.name or row.author.phone
    return {
        'id': str(row.id),
        'authorRole': row.author_role,
        'authorName': author_name,
        'body': row.body,
        'createdAt': row.created_at.isoformat(),
    }


def serialize_ticket(row: SupportTicket, *, include_messages=False) -> dict:
    user = row.user
    payload = {
        'id': str(row.id),
        'subject': row.subject,
        'status': row.status,
        'message': row.message,
        'resolutionNote': row.resolution_note,
        'userId': str(user.id),
        'userName': user.name or 'Unnamed',
        'userPhone': user.phone,
        'userEmail': user.email or '',
        'createdAt': row.created_at.isoformat(),
        'updatedAt': row.updated_at.isoformat(),
        'resolvedAt': row.resolved_at.isoformat() if row.resolved_at else None,
        'messageCount': row.messages.count(),
    }
    if include_messages:
        payload['messages'] = [
            serialize_ticket_message(message)
            for message in row.messages.select_related('author')
        ]
    return payload


@transaction.atomic
def admin_reply_to_ticket(ticket: SupportTicket, admin_user, body: str) -> SupportTicketMessage:
    body = body.strip()
    if not body:
        raise ValueError('Reply message is required.')
    message = SupportTicketMessage.objects.create(
        ticket=ticket,
        author=admin_user,
        author_role=SupportTicketMessage.AuthorRole.ADMIN,
        body=body,
    )
    if ticket.status == SupportTicket.Status.OPEN:
        ticket.status = SupportTicket.Status.IN_PROGRESS
        ticket.save(update_fields=['status', 'updated_at'])
    _notify_user(
        ticket.user,
        title='Support update on your ticket',
        message=f'Re: {ticket.subject}\n\n{body}',
        reference_id=str(ticket.id),
    )
    _upsert(
        AdminNotification.Kind.SUPPORT_TICKET,
        reference_id=str(ticket.id),
        title=f'Support: {ticket.subject[:120]}',
        message=f'In progress — replied to {ticket.user.phone}',
        action_tab='support',
    )
    return message


@transaction.atomic
def admin_resolve_ticket(
    ticket: SupportTicket,
    admin_user,
    *,
    resolution_note: str,
    notify_user: bool = True,
) -> SupportTicket:
    resolution_note = resolution_note.strip()
    if not resolution_note:
        raise ValueError('Resolution note is required.')
    ticket.status = SupportTicket.Status.RESOLVED
    ticket.resolution_note = resolution_note
    ticket.resolved_at = timezone.now()
    ticket.resolved_by = admin_user
    ticket.save(update_fields=['status', 'resolution_note', 'resolved_at', 'resolved_by', 'updated_at'])
    SupportTicketMessage.objects.create(
        ticket=ticket,
        author=admin_user,
        author_role=SupportTicketMessage.AuthorRole.ADMIN,
        body=f'Resolved: {resolution_note}',
    )
    if notify_user:
        _notify_user(
            ticket.user,
            title='Your support ticket is resolved',
            message=f'{ticket.subject}\n\n{resolution_note}',
            reference_id=str(ticket.id),
        )
    AdminNotification.objects.filter(
        kind=AdminNotification.Kind.SUPPORT_TICKET,
        reference_id=str(ticket.id),
    ).update(is_read=True, read_at=timezone.now())
    return ticket


@transaction.atomic
def admin_reopen_ticket(ticket: SupportTicket, admin_user, note: str = '') -> SupportTicket:
    ticket.status = SupportTicket.Status.OPEN
    ticket.resolution_note = ''
    ticket.resolved_at = None
    ticket.resolved_by = None
    ticket.save(update_fields=['status', 'resolution_note', 'resolved_at', 'resolved_by', 'updated_at'])
    if note.strip():
        SupportTicketMessage.objects.create(
            ticket=ticket,
            author=admin_user,
            author_role=SupportTicketMessage.AuthorRole.ADMIN,
            body=f'Reopened: {note.strip()}',
        )
    _upsert(
        AdminNotification.Kind.SUPPORT_TICKET,
        reference_id=str(ticket.id),
        title=f'Support: {ticket.subject[:120]}',
        message=f'Reopened for {ticket.user.phone}',
        action_tab='support',
    )
    return ticket
