from django.contrib import admin

from .models import (
    InvestmentFaq,
    InvestmentPlan,
    PaymentOrder,
    Transaction,
    UserInvestment,
    Wallet,
    WalletTransaction,
)

class ReadOnlyFinancialAdmin(admin.ModelAdmin):
    """Financial state must change through transactional services, never CRUD."""

    def get_readonly_fields(self, request, obj=None):
        return tuple(field.name for field in self.model._meta.fields)

    def has_add_permission(self, request):
        return False

    def has_delete_permission(self, request, obj=None):
        return False


@admin.register(Wallet)
class WalletAdmin(ReadOnlyFinancialAdmin):
    list_display = ('user', 'balance', 'updated_at')
    search_fields = ('user__phone', 'user__name')


@admin.register(WalletTransaction)
class WalletTransactionAdmin(ReadOnlyFinancialAdmin):
    list_display = ('wallet', 'type', 'amount', 'status', 'created_at')
    list_filter = ('type', 'status')
    search_fields = ('wallet__user__phone',)


@admin.register(Transaction)
class TransactionAdmin(ReadOnlyFinancialAdmin):
    list_display = ('user', 'reference_id', 'type', 'amount', 'status', 'created_at')
    list_filter = ('type', 'status')
    search_fields = ('user__phone', 'reference_id')


@admin.register(PaymentOrder)
class PaymentOrderAdmin(ReadOnlyFinancialAdmin):
    list_display = ('user', 'gateway', 'order_id', 'amount', 'status', 'created_at')
    list_filter = ('gateway', 'status')
    search_fields = ('user__phone', 'order_id', 'payment_id')


@admin.register(UserInvestment)
class UserInvestmentAdmin(ReadOnlyFinancialAdmin):
    list_display = ('user', 'plan', 'amount', 'status', 'invested_at')
    list_filter = ('status', 'plan')
    search_fields = ('user__phone', 'reference_id')


admin.site.register(InvestmentPlan)
admin.site.register(InvestmentFaq)
