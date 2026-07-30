"""User-facing support ticket helpers."""

from django.db import transaction

from engagement.models import SupportTicket, SupportTicketMessage


def create_ticket_for_user(user, *, subject: str, message: str = '') -> SupportTicket:
    with transaction.atomic():
        ticket = SupportTicket.objects.create(
            user=user,
            subject=subject.strip(),
            message=message.strip(),
        )
        if message.strip():
            SupportTicketMessage.objects.create(
                ticket=ticket,
                author=user,
                author_role=SupportTicketMessage.AuthorRole.USER,
                body=message.strip(),
            )
        try:
            from adminpanel.notifications_service import _upsert
            from adminpanel.models import AdminNotification

            user_label = user.name or user.phone
            _upsert(
                AdminNotification.Kind.SUPPORT_TICKET,
                reference_id=str(ticket.id),
                title=f'New support ticket: {subject[:120]}',
                message=f'{user_label} opened a support request.',
                action_tab='support',
            )
        except Exception:
            pass
    return ticket
