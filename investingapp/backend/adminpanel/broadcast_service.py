"""Push announcements and news to all app users."""

from django.db import transaction

from accounts.models import User
from engagement.models import Notification

from .models import AdminBroadcast

VALID_CATEGORIES = {choice.value for choice in AdminBroadcast.Category}


@transaction.atomic
def send_broadcast(*, admin_user, title: str, message: str, category: str = 'announcement', audience: str = 'customers'):
    title = title.strip()
    message = message.strip()
    if not title:
        raise ValueError('Title is required.')
    if not message:
        raise ValueError('Message is required.')
    if category not in VALID_CATEGORIES:
        raise ValueError('Invalid category. Use announcement, news, or important.')

    broadcast = AdminBroadcast.objects.create(
        title=title[:200],
        message=message,
        category=category,
        created_by=admin_user,
        recipient_count=0,
    )

    users = User.objects.filter(is_active=True)
    if audience != 'all':
        users = users.filter(is_staff=False)

    reference_id = str(broadcast.id)
    batch: list[Notification] = []
    recipient_count = 0
    for user in users.iterator(chunk_size=500):
        batch.append(
            Notification(
                user=user,
                title=title[:200],
                message=message,
                type=category,
                reference_id=reference_id,
            )
        )
        if len(batch) >= 500:
            Notification.objects.bulk_create(batch)
            recipient_count += len(batch)
            batch = []
    if batch:
        Notification.objects.bulk_create(batch)
        recipient_count += len(batch)

    broadcast.recipient_count = recipient_count
    broadcast.save(update_fields=['recipient_count'])
    return broadcast


def serialize_broadcast(row: AdminBroadcast) -> dict:
    author_name = ''
    if row.created_by_id:
        author_name = row.created_by.name or row.created_by.phone
    return {
        'id': str(row.id),
        'title': row.title,
        'message': row.message,
        'category': row.category,
        'recipientCount': row.recipient_count,
        'createdByName': author_name,
        'createdAt': row.created_at.isoformat(),
    }
