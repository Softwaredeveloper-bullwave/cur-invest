from django.contrib import admin

from .models import AdminActionAudit, ApplicationErrorEvent


@admin.register(AdminActionAudit)
class AdminActionAuditAdmin(admin.ModelAdmin):
    list_display = ('actor', 'action', 'target_type', 'target_id', 'ip_address', 'created_at')
    list_filter = ('action', 'target_type')
    search_fields = ('actor__phone', 'target_id', 'summary')
    readonly_fields = (
        'id',
        'actor',
        'action',
        'target_type',
        'target_id',
        'summary',
        'metadata',
        'ip_address',
        'created_at',
    )

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(ApplicationErrorEvent)
class ApplicationErrorEventAdmin(admin.ModelAdmin):
    list_display = (
        'source',
        'severity',
        'exception_type',
        'status',
        'occurrence_count',
        'last_seen_at',
    )
    list_filter = ('source', 'severity', 'status')
    search_fields = ('message', 'exception_type', 'logger_name', 'location', 'user__phone')
    readonly_fields = (
        'id',
        'source',
        'severity',
        'fingerprint',
        'logger_name',
        'message',
        'exception_type',
        'location',
        'method',
        'status_code',
        'user',
        'context',
        'occurrence_count',
        'first_seen_at',
        'last_seen_at',
    )
