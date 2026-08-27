from django.urls import path

from . import views

urlpatterns = [
    path('forex/overview/', views.ForexOverviewView.as_view(), name='forex-overview'),
    path('forex/pairs/', views.ForexPairsView.as_view(), name='forex-pairs'),
    path('forex/pairs/<str:pair_id>/chart/', views.ForexChartView.as_view(), name='forex-pair-chart'),
    path('forex/pairs/<str:pair_id>/', views.ForexPairDetailView.as_view(), name='forex-pair-detail'),
    path('forex/search/', views.ForexSearchView.as_view(), name='forex-search'),
    path('forex/screener/', views.ForexScreenerView.as_view(), name='forex-screener'),
    path('forex/movers/', views.ForexMoversView.as_view(), name='forex-movers'),
    path('forex/watchlist/', views.ForexWatchlistView.as_view(), name='forex-watchlist'),
    path('forex/watchlist/<uuid:item_id>/', views.ForexWatchlistDetailView.as_view(), name='forex-watchlist-detail'),
    path('forex/news/', views.ForexNewsView.as_view(), name='forex-news'),
    path('forex/portfolio/', views.ForexPortfolioView.as_view(), name='forex-portfolio'),
    path('forex/paper-orders/', views.ForexPaperOrderView.as_view(), name='forex-paper-orders'),
    path('forex/transactions/', views.ForexTransactionsView.as_view(), name='forex-transactions'),
    path('forex/wallet/', views.ForexWalletView.as_view(), name='forex-wallet'),
    path('forex/health/', views.ForexHealthView.as_view(), name='forex-health'),
    path('forex/notification-preferences/', views.ForexNotificationPreferenceView.as_view(), name='forex-notif-prefs'),
    path('forex/trading-status/', views.ForexLiveTradingStatusView.as_view(), name='forex-trading-status'),
]
