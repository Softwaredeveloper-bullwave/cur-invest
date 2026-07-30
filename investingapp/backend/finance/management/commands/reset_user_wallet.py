"""Reset a user's wallet balance and optional demo holdings for clean testing."""

from decimal import Decimal

from django.core.management.base import BaseCommand, CommandError
from django.db import transaction

from accounts.models import User
from accounts.otp_utils import normalize_phone
from finance.models import Wallet, WalletTransaction
from stocks.models import StockHolding


class Command(BaseCommand):
    help = 'Reset wallet balance to ₹0 (and optionally clear demo stock holdings) for a user.'

    def add_arguments(self, parser):
        parser.add_argument('--phone', required=True, help='User phone number (10 digits).')
        parser.add_argument(
            '--clear-holdings',
            action='store_true',
            help='Also remove all stock holdings so portfolio shows ₹0.',
        )
        parser.add_argument(
            '--clear-transactions',
            action='store_true',
            help='Delete wallet transaction history for this user.',
        )

    @transaction.atomic
    def handle(self, *args, **options):
        phone = normalize_phone(options['phone'])
        if not phone:
            raise CommandError('Invalid phone number.')

        try:
            user = User.objects.get(phone=phone)
        except User.DoesNotExist as exc:
            raise CommandError(f'No user found with phone {phone}.') from exc

        wallet, _ = Wallet.objects.get_or_create(user=user)
        old_balance = wallet.balance
        wallet.balance = Decimal('0')
        wallet.save(update_fields=['balance'])

        cleared_txs = 0
        if options.get('clear_transactions'):
            cleared_txs, _ = WalletTransaction.objects.filter(wallet=wallet).delete()

        cleared_holdings = 0
        if options.get('clear_holdings'):
            cleared_holdings, _ = StockHolding.objects.filter(user=user).delete()

        self.stdout.write(
            self.style.SUCCESS(
                f'User {phone}: wallet {old_balance} → ₹0'
                + (f', removed {cleared_holdings} holdings' if cleared_holdings else '')
                + (f', removed {cleared_txs} wallet transactions' if cleared_txs else '')
            )
        )
