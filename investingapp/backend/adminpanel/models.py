import uuid

from django.conf import settings
from django.db import models


class AdminActionAudit(models.Model):
    """Immutable audit trail for privileged React-admin actions."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    actor = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='admin_actions',
    )
    action = models.CharField(max_length=80)
    target_type = models.CharField(max_length=80)
    target_id = models.CharField(max_length=80)
    summary = models.CharField(max_length=500, blank=True, default='')
    metadata = models.JSONField(default=dict, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['actor', 'created_at'], name='adminpanel_actor_i_827c40_idx'),
            models.Index(fields=['target_type', 'target_id'], name='adminpanel_target__cedd64_idx'),
        ]

    def __str__(self):
        return f'{self.action} {self.target_type}:{self.target_id}'


class ApplicationErrorEvent(models.Model):
    """Sanitized, deduplicated application error visible to staff."""

    class Source(models.TextChoices):
        BACKEND = 'backend', 'Backend'
        FLUTTER = 'flutter', 'Flutter'

    class Severity(models.TextChoices):
        WARNING = 'warning', 'Warning'
        ERROR = 'error', 'Error'
        CRITICAL = 'critical', 'Critical'

    class Status(models.TextChoices):
        OPEN = 'open', 'Open'
        RESOLVED = 'resolved', 'Resolved'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    source = models.CharField(max_length=20, choices=Source.choices)
    severity = models.CharField(max_length=20, choices=Severity.choices, default=Severity.ERROR)
    fingerprint = models.CharField(max_length=64)
    logger_name = models.CharField(max_length=160, blank=True, default='')
    message = models.CharField(max_length=500)
    exception_type = models.CharField(max_length=160, blank=True, default='')
    location = models.CharField(max_length=300, blank=True, default='')
    method = models.CharField(max_length=12, blank=True, default='')
    status_code = models.PositiveSmallIntegerField(null=True, blank=True)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='application_errors',
    )
    context = models.JSONField(default=dict, blank=True)
    occurrence_count = models.PositiveIntegerField(default=1)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.OPEN)
    resolved_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='resolved_application_errors',
    )
    resolved_at = models.DateTimeField(null=True, blank=True)
    first_seen_at = models.DateTimeField(auto_now_add=True)
    last_seen_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-last_seen_at']
        constraints = [
            models.UniqueConstraint(
                fields=['source', 'fingerprint'],
                name='adminpanel_unique_error_fingerprint',
            ),
        ]
        indexes = [
            models.Index(fields=['status', 'last_seen_at'], name='adminpanel_error_status_idx'),
            models.Index(fields=['source', 'last_seen_at'], name='adminpanel_error_source_idx'),
            models.Index(fields=['severity', 'last_seen_at'], name='adminpanel_error_severity_idx'),
        ]

    def __str__(self):
        return f'{self.source}:{self.exception_type or self.logger_name} ({self.occurrence_count})'


class AdminNotification(models.Model):
    """Staff inbox items surfaced in the admin panel notification bell."""

    class Kind(models.TextChoices):
        SUPPORT_TICKET = 'support_ticket', 'Support ticket'
        KYC_REVIEW = 'kyc_review', 'KYC review'
        PAYMENT_FAILED = 'payment_failed', 'Payment failed'
        PAYOUT_FAILED = 'payout_failed', 'Payout failed'
        CRITICAL_ERROR = 'critical_error', 'Critical error'
        NEW_USER = 'new_user', 'New user'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    kind = models.CharField(max_length=30, choices=Kind.choices)
    title = models.CharField(max_length=200)
    message = models.CharField(max_length=500)
    reference_id = models.CharField(max_length=80, blank=True, default='')
    action_tab = models.CharField(max_length=30, blank=True, default='')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    read_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['is_read', 'created_at'], name='adminpanel_notif_read_idx'),
        ]
        constraints = [
            models.UniqueConstraint(
                fields=['kind', 'reference_id'],
                name='adminpanel_unique_notification_ref',
            ),
        ]


class AdminBroadcast(models.Model):
    """Staff-composed push notification sent to app users."""

    class Category(models.TextChoices):
        ANNOUNCEMENT = 'announcement', 'Announcement'
        NEWS = 'news', 'News'
        IMPORTANT = 'important', 'Important'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=200)
    message = models.TextField()
    category = models.CharField(max_length=20, choices=Category.choices, default=Category.ANNOUNCEMENT)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='admin_broadcasts',
    )
    recipient_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f'{self.category}: {self.title[:60]}'
