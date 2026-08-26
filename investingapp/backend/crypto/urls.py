from django.urls import path

from . import views

urlpatterns = [
    path('crypto/market-preference/', views.MarketPreferenceView.as_view(), name='crypto-market-preference'),
    path('crypto/overview/', views.CryptoOverviewView.as_view(), name='crypto-overview'),
    path('crypto/assets/', views.CryptoAssetsView.as_view(), name='crypto-assets'),
    path('crypto/assets/<str:asset_id>/chart/', views.CryptoChartView.as_view(), name='crypto-asset-chart'),
    path('crypto/assets/<str:asset_id>/', views.CryptoAssetDetailView.as_view(), name='crypto-asset-detail'),
    path('crypto/search/', views.CryptoSearchView.as_view(), name='crypto-search'),
    path('crypto/screener/', views.CryptoScreenerView.as_view(), name='crypto-screener'),
    path('crypto/movers/', views.CryptoMoversView.as_view(), name='crypto-movers'),
    path('crypto/watchlist/', views.CryptoWatchlistView.as_view(), name='crypto-watchlist'),
    path('crypto/watchlist/<uuid:item_id>/', views.CryptoWatchlistDetailView.as_view(), name='crypto-watchlist-detail'),
    path('crypto/news/', views.CryptoNewsView.as_view(), name='crypto-news'),
    path('crypto/portfolio/', views.CryptoPortfolioView.as_view(), name='crypto-portfolio'),
    path('crypto/paper-orders/', views.CryptoPaperOrderView.as_view(), name='crypto-paper-orders'),
    path('crypto/transactions/', views.CryptoTransactionsView.as_view(), name='crypto-transactions'),
    path('crypto/wallet/', views.CryptoWalletView.as_view(), name='crypto-wallet'),
    path('crypto/health/', views.CryptoHealthView.as_view(), name='crypto-health'),
    path('crypto/notification-preferences/', views.CryptoNotificationPreferenceView.as_view(), name='crypto-notif-prefs'),
    path('crypto/price-alerts/', views.CryptoPriceAlertsView.as_view(), name='crypto-price-alerts'),
    path('crypto/trading-status/', views.CryptoLiveTradingStatusView.as_view(), name='crypto-trading-status'),
]
