from django.contrib import admin

from .models import (
    ForexApiRequestLog,
    ForexHolding,
    ForexMarketSnapshot,
    ForexNewsArticle,
    ForexPair,
    ForexPracticeWallet,
    ForexProviderHealth,
    ForexTransaction,
    ForexWatchlistItem,
)


@admin.register(ForexPair)
class ForexPairAdmin(admin.ModelAdmin):
    list_display = ('id', 'symbol', 'name', 'category', 'is_active')
    list_filter = ('category', 'is_active')
    search_fields = ('id', 'symbol', 'name')


@admin.register(ForexMarketSnapshot)
class ForexMarketSnapshotAdmin(admin.ModelAdmin):
    list_display = ('pair', 'current_price', 'price_change_percentage_24h', 'fetched_at')


@admin.register(ForexWatchlistItem)
class ForexWatchlistItemAdmin(admin.ModelAdmin):
    list_display = ('user', 'pair', 'added_at')


@admin.register(ForexPracticeWallet)
class ForexPracticeWalletAdmin(admin.ModelAdmin):
    list_display = ('user', 'balance', 'currency', 'updated_at')


@admin.register(ForexHolding)
class ForexHoldingAdmin(admin.ModelAdmin):
    list_display = ('user', 'pair', 'quantity', 'avg_price')


@admin.register(ForexTransaction)
class ForexTransactionAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'pair', 'tx_type', 'total_value', 'is_paper', 'created_at')
    list_filter = ('tx_type', 'is_paper')


@admin.register(ForexNewsArticle)
class ForexNewsArticleAdmin(admin.ModelAdmin):
    list_display = ('title', 'source', 'category', 'published_at')
    list_filter = ('category', 'source')


@admin.register(ForexProviderHealth)
class ForexProviderHealthAdmin(admin.ModelAdmin):
    list_display = ('service', 'status', 'provider_name', 'last_success_at')


@admin.register(ForexApiRequestLog)
class ForexApiRequestLogAdmin(admin.ModelAdmin):
    list_display = ('service', 'endpoint', 'success', 'status_code', 'created_at')
    list_filter = ('service', 'success')
