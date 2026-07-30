from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import BankAccount, EmailOTPVerification, KycDocument, OTPVerification, User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('phone', 'name', 'kyc_status', 'pan_status', 'is_staff')
    search_fields = ('phone', 'name', 'email')
    ordering = ('phone',)
    fieldsets = (
        (None, {'fields': ('phone', 'password')}),
        ('Profile', {'fields': ('name', 'email', 'avatar_url', 'referral_code', 'referred_by')}),
        ('Verification', {'fields': ('pan_status', 'kyc_status', 'has_completed_onboarding')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )
    add_fieldsets = ((None, {'classes': ('wide',), 'fields': ('phone', 'password1', 'password2')}),)


admin.site.register(OTPVerification)
admin.site.register(KycDocument)


@admin.register(BankAccount)
class BankAccountAdmin(admin.ModelAdmin):
    list_display = ('user', 'bank_name', 'ifsc', 'verification_status', 'verified_at')
    list_filter = ('verification_status', 'verification_provider')
    search_fields = ('user__phone', 'account_holder_name', 'ifsc')

    def get_readonly_fields(self, request, obj=None):
        return tuple(field.name for field in self.model._meta.fields)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
