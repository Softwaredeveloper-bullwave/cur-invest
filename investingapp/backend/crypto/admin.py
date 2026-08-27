from django.contrib import admin

from .models import (
    CryptoApiRequestLog,
    CryptoAsset,
    CryptoHolding,
    CryptoMarketSnapshot,
    CryptoNewsArticle,
    CryptoNotificationPreference,
    CryptoPracticeWallet,
    CryptoPriceAlert,
    CryptoProviderHealth,
    CryptoTransaction,
    CryptoWatchlistItem,
    UserMarketPreference,
)


@admin.register(UserMarketPreference)
class UserMarketPreferenceAdmin(admin.ModelAdmin):
    list_display = (
        'user',
        'indian_market_enabled',
        'crypto_market_enabled',
        'forex_market_enabled',
        'active_market',
        'has_completed_selection',
        'updated_at',
    )
    list_filter = ('indian_market_enabled', 'crypto_market_enabled', 'has_completed_selection')
    search_fields = ('user__phone', 'user__email', 'user__name')


@admin.register(CryptoAsset)
class CryptoAssetAdmin(admin.ModelAdmin):
    list_display = ('id', 'symbol', 'name', 'market_cap_rank', 'is_active', 'updated_at')
    list_filter = ('is_active',)
    search_fields = ('id', 'symbol', 'name')


@admin.register(CryptoMarketSnapshot)
class CryptoMarketSnapshotAdmin(admin.ModelAdmin):
    list_display = ('asset', 'current_price', 'price_change_percentage_24h', 'market_cap', 'fetched_at')
    search_fields = ('asset__symbol', 'asset__id')


@admin.register(CryptoWatchlistItem)
class CryptoWatchlistItemAdmin(admin.ModelAdmin):
    list_display = ('user', 'asset', 'added_at')
    search_fields = ('user__phone', 'asset__symbol')


@admin.register(CryptoPracticeWallet)
class CryptoPracticeWalletAdmin(admin.ModelAdmin):
    list_display = ('user', 'balance', 'currency', 'updated_at')
    search_fields = ('user__phone',)


@admin.register(CryptoHolding)
class CryptoHoldingAdmin(admin.ModelAdmin):
    list_display = ('user', 'asset', 'quantity', 'avg_price', 'updated_at')
    search_fields = ('user__phone', 'asset__symbol')


@admin.register(CryptoTransaction)
class CryptoTransactionAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'user',
        'asset',
        'tx_type',
        'quantity',
        'price',
        'total_value',
        'status',
        'is_paper',
        'created_at',
    )
    list_filter = ('tx_type', 'status', 'is_paper')
    search_fields = ('user__phone', 'asset__symbol', 'external_id')
    readonly_fields = ('created_at',)


@admin.register(CryptoNewsArticle)
class CryptoNewsArticleAdmin(admin.ModelAdmin):
    list_display = ('title', 'source', 'category', 'published_at')
    list_filter = ('category', 'source')
    search_fields = ('title', 'source')


@admin.register(CryptoProviderHealth)
class CryptoProviderHealthAdmin(admin.ModelAdmin):
    list_display = (
        'service',
        'status',
        'provider_name',
        'avg_response_ms',
        'last_success_at',
        'error_count',
        'rate_limit_hits',
    )
    readonly_fields = (
        'service',
        'status',
        'provider_name',
        'last_success_at',
        'last_error_at',
        'last_error_message',
        'avg_response_ms',
        'rate_limit_hits',
        'error_count',
        'success_count',
        'data_freshness_seconds',
        'updated_at',
    )

    def has_add_permission(self, request):
        return False


@admin.register(CryptoApiRequestLog)
class CryptoApiRequestLogAdmin(admin.ModelAdmin):
    list_display = ('service', 'endpoint', 'success', 'status_code', 'response_ms', 'created_at')
    list_filter = ('service', 'success')
    readonly_fields = ('service', 'endpoint', 'success', 'status_code', 'response_ms', 'error_type', 'created_at')

    def has_add_permission(self, request):
        return False


admin.site.register(CryptoPriceAlert)
admin.site.register(CryptoNotificationPreference)
