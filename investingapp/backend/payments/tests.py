from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from finance.models import PaymentOrder, Wallet, WalletTransaction
from payments.deposit_service import credit_payment_order, webhook_indicates_paid

User = get_user_model()


class DepositServiceTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9000000001', password='x')
        self.wallet = Wallet.objects.create(user=self.user, balance=Decimal('100'))
        self.order = PaymentOrder.objects.create(
            user=self.user,
            gateway='cashfree',
            order_id='bw_test123',
            amount=Decimal('500'),
        )

    def test_credit_payment_order_updates_balance(self):
        wallet = credit_payment_order(payment_order=self.order, payment_id='cf_pay_1')
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, PaymentOrder.Status.PAID)
        self.assertEqual(wallet.balance, Decimal('600'))
        self.assertEqual(WalletTransaction.objects.filter(wallet=wallet).count(), 1)

    def test_credit_payment_order_is_idempotent(self):
        credit_payment_order(payment_order=self.order, payment_id='cf_pay_1')
        credit_payment_order(payment_order=self.order, payment_id='cf_pay_1')
        self.wallet.refresh_from_db()
        self.assertEqual(self.wallet.balance, Decimal('600'))
        self.assertEqual(WalletTransaction.objects.count(), 1)

    def test_webhook_indicates_paid(self):
        payload = {
            'type': 'PAYMENT_SUCCESS_WEBHOOK',
            'data': {
                'order': {'order_id': 'bw_abc', 'order_status': 'PAID'},
                'payment': {'cf_payment_id': 'pay_99', 'payment_status': 'SUCCESS'},
            },
        }
        is_paid, order_id, payment_id = webhook_indicates_paid(payload)
        self.assertTrue(is_paid)
        self.assertEqual(order_id, 'bw_abc')
        self.assertEqual(payment_id, 'pay_99')


@override_settings(
    CASHFREE_CLIENT_ID='test_id',
    CASHFREE_CLIENT_SECRET='test_secret',
)
class VerifyPaymentViewTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9000000002', password='x')
        Wallet.objects.create(user=self.user, balance=Decimal('0'))
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.order = PaymentOrder.objects.create(
            user=self.user,
            gateway='cashfree',
            order_id='bw_verify_me',
            amount=Decimal('250'),
        )

    @patch('payments.views.fetch_order_status')
    def test_verify_payment_credits_wallet(self, mock_fetch):
        mock_fetch.return_value = {'order_status': 'PAID', 'payment': {'cf_payment_id': 'cf_1'}}
        res = self.client.post('/api/v1/verify-payment/', {'orderId': 'bw_verify_me'}, format='json')
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data['success'])
        self.assertEqual(res.data['balance'], 250.0)
        self.order.refresh_from_db()
        self.assertEqual(self.order.status, PaymentOrder.Status.PAID)

    @patch('payments.views.fetch_order_status')
    def test_verify_payment_pending_returns_409(self, mock_fetch):
        mock_fetch.return_value = {'order_status': 'ACTIVE'}
        res = self.client.post('/api/v1/verify-payment/', {'orderId': 'bw_verify_me'}, format='json')
        self.assertEqual(res.status_code, 409)
