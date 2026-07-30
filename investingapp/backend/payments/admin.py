from django.contrib import admin

from .models import PayoutRecord


@admin.register(PayoutRecord)
class PayoutRecordAdmin(admin.ModelAdmin):
    list_display = ('transfer_id', 'user', 'amount', 'status', 'created_at', 'completed_at')
    list_filter = ('status',)
    search_fields = ('transfer_id', 'reference_id', 'user__phone')

    def get_readonly_fields(self, request, obj=None):
        return tuple(field.name for field in self.model._meta.fields)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
