from django.urls import path

from .views import (
    CreatePaymentView,
    PaymentStatusView,
    PaymentWebhookView,
    PayoutWebhookView,
    VerifyPaymentView,
    WithdrawView,
)

urlpatterns = [
    path('create-payment/', CreatePaymentView.as_view(), name='create-payment'),
    path('verify-payment/', VerifyPaymentView.as_view(), name='verify-payment'),
    path('payment-webhook/', PaymentWebhookView.as_view(), name='payment-webhook'),
    path('payment-status/<str:order_id>/', PaymentStatusView.as_view(), name='payment-status'),
    path('withdraw/', WithdrawView.as_view(), name='withdraw'),
    path('payout-webhook/', PayoutWebhookView.as_view(), name='payout-webhook'),
]
