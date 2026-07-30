from decimal import Decimal

from django.test import TestCase

from accounts.models import User

from .models import PracticeWalletTransaction, Wallet
from .practice_wallet_service import (
    credit_practice_wallet,
    debit_practice_wallet,
    get_practice_wallet,
)


class PracticeWalletTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            phone='9444444444',
            name='Practice User',
        )

    def test_starts_with_one_lakh_and_does_not_touch_real_wallet(self):
        real_wallet = Wallet.objects.create(user=self.user, balance=Decimal('500.00'))

        practice = get_practice_wallet(self.user)
        debit_practice_wallet(self.user, Decimal('2500.00'), reference='TEST-BUY')

        practice.refresh_from_db()
        real_wallet.refresh_from_db()
        self.assertEqual(practice.balance, Decimal('97500.00'))
        self.assertEqual(real_wallet.balance, Decimal('500.00'))

    def test_automatically_refills_when_balance_falls_below_ten_thousand(self):
        wallet = debit_practice_wallet(
            self.user,
            Decimal('90001.00'),
            reference='LOW-BALANCE-BUY',
        )

        self.assertEqual(wallet.balance, Decimal('100000.00'))
        refill = wallet.transactions.get(type=PracticeWalletTransaction.TxType.REFILL)
        self.assertEqual(refill.amount, Decimal('90001.00'))
        self.assertEqual(refill.balance_after, Decimal('100000.00'))

    def test_sell_credits_practice_funds(self):
        wallet = credit_practice_wallet(
            self.user,
            Decimal('1250.00'),
            reference='TEST-SELL',
        )

        self.assertEqual(wallet.balance, Decimal('101250.00'))
