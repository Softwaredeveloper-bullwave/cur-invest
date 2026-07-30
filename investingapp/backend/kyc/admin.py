from django.contrib import admin, messages
from django.utils import timezone

from .manual_service import approve_kyc_request, reject_kyc_request
from .fno_service import approve_fno_request, reject_fno_request
from .models import (
    BankVerificationRequest,
    FnoEligibilityRequest,
    KYCRequest,
    KYCRequestImage,
    KycProfile,
    VerificationAuditLog,
)


@admin.register(KYCRequest)
class KYCRequestAdmin(admin.ModelAdmin):
    list_display = (
        'pan_number',
        'full_name',
        'user',
        'status',
        'created_at',
        'reviewed_at',
    )
    list_filter = ('status',)
    search_fields = ('pan_number', 'full_name', 'user__phone')
    readonly_fields = (
        'id',
        'user',
        'pan_number',
        'full_name',
        'dob',
        'pan_image',
        'reviewed_by',
        'reviewed_at',
        'created_at',
        'updated_at',
    )
    actions = ['approve_selected', 'reject_selected']

    @admin.action(description='Approve selected KYC requests')
    def approve_selected(self, request, queryset):
        count = 0
        for req in queryset.filter(status=KYCRequest.Status.PENDING):
            approve_kyc_request(req, request.user)
            count += 1
        self.message_user(request, f'Approved {count} request(s).', messages.SUCCESS)

    @admin.action(description='Reject selected (reason: see admin notes)')
    def reject_selected(self, request, queryset):
        count = 0
        for req in queryset.filter(status=KYCRequest.Status.PENDING):
            reject_kyc_request(req, request.user, 'Rejected from Django admin.')
            count += 1
        self.message_user(request, f'Rejected {count} request(s).', messages.WARNING)


@admin.register(FnoEligibilityRequest)
class FnoEligibilityRequestAdmin(admin.ModelAdmin):
    list_display = ('user', 'proof_type', 'status', 'portfolio_value', 'created_at', 'reviewed_at')
    list_filter = ('status', 'proof_type')
    search_fields = ('user__phone', 'user__name')
    readonly_fields = (
        'id',
        'user',
        'proof_type',
        'document',
        'portfolio_value',
        'reviewed_by',
        'reviewed_at',
        'created_at',
        'updated_at',
    )
    actions = ['approve_selected', 'reject_selected']

    @admin.action(description='Approve selected F&O requests')
    def approve_selected(self, request, queryset):
        count = 0
        for req in queryset.filter(status=FnoEligibilityRequest.Status.PENDING):
            approve_fno_request(req, request.user)
            count += 1
        self.message_user(request, f'Approved {count} F&O request(s).', messages.SUCCESS)

    @admin.action(description='Reject selected F&O requests')
    def reject_selected(self, request, queryset):
        count = 0
        for req in queryset.filter(status=FnoEligibilityRequest.Status.PENDING):
            reject_fno_request(req, request.user, 'Rejected from Django admin.')
            count += 1
        self.message_user(request, f'Rejected {count} request(s).', messages.WARNING)


@admin.register(KYCRequestImage)
class KYCRequestImageAdmin(admin.ModelAdmin):
    list_display = ('request', 'sort_order', 'created_at')
    readonly_fields = ('id', 'request', 'image', 'sort_order', 'created_at')


@admin.register(KycProfile)
class KycProfileAdmin(admin.ModelAdmin):
    list_display = ('user', 'overall_status', 'pan_status', 'bank_status', 'name_match_passed', 'verified_at')
    search_fields = ('user__phone', 'pan_number', 'account_holder_name')

    def get_readonly_fields(self, request, obj=None):
        return tuple(field.name for field in self.model._meta.fields)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(BankVerificationRequest)
class BankVerificationRequestAdmin(admin.ModelAdmin):
    list_display = ('user', 'ifsc', 'upi_vpa', 'status', 'submitted_at', 'review_due_at', 'reviewed_by')
    list_filter = ('status',)
    search_fields = ('user__phone', 'account_holder_name', 'ifsc')
    readonly_fields = (
        'id',
        'user',
        'account_holder_name',
        'account_number',
        'ifsc',
        'bank_name',
        'bank_branch',
        'upi_vpa',
        'upi_mobile',
        'status',
        'review_note',
        'submitted_at',
        'review_due_at',
        'reviewed_by',
        'reviewed_at',
        'updated_at',
    )


@admin.register(VerificationAuditLog)
class VerificationAuditLogAdmin(admin.ModelAdmin):
    list_display = ('user', 'step', 'status', 'message', 'created_at')
    list_filter = ('step', 'status')
    search_fields = ('user__phone', 'message')
