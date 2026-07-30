"""Virtual ₹1 lakh wallet for paper-market practice."""

from decimal import Decimal

from django.db import transaction
from django.utils import timezone

from .models import PracticeWallet, PracticeWalletTransaction


INITIAL_BALANCE = Decimal('100000.00')
REFILL_THRESHOLD = Decimal('10000.00')


class PracticeWalletError(Exception):
    pass


def get_practice_wallet(user, *, lock=False) -> PracticeWallet:
    queryset = PracticeWallet.objects
    if lock:
        queryset = queryset.select_for_update()
    wallet, _ = queryset.get_or_create(
        user=user,
        defaults={'balance': INITIAL_BALANCE},
    )
    return wallet


def _refill_if_low(wallet: PracticeWallet) -> Decimal:
    if wallet.balance >= REFILL_THRESHOLD:
        return Decimal('0')
    amount = INITIAL_BALANCE - wallet.balance
    if amount <= 0:
        return Decimal('0')
    wallet.balance = INITIAL_BALANCE
    wallet.last_refilled_at = timezone.now()
    wallet.save(update_fields=['balance', 'last_refilled_at', 'updated_at'])
    PracticeWalletTransaction.objects.create(
        wallet=wallet,
        type=PracticeWalletTransaction.TxType.REFILL,
        amount=amount,
        balance_after=wallet.balance,
        reference='AUTO-REFILL',
        description='Automatic paper-trading balance refill.',
    )
    return amount


@transaction.atomic
def debit_practice_wallet(user, amount, *, reference='', description='') -> PracticeWallet:
    amount = Decimal(str(amount)).quantize(Decimal('0.01'))
    if amount <= 0:
        raise PracticeWalletError('Trade amount must be greater than zero.')
    wallet = get_practice_wallet(user, lock=True)
    _refill_if_low(wallet)
    if wallet.balance < amount:
        raise PracticeWalletError(
            f'Insufficient practice funds. Need ₹{amount:,.2f}; available ₹{wallet.balance:,.2f}.'
        )
    wallet.balance -= amount
    wallet.save(update_fields=['balance', 'updated_at'])
    PracticeWalletTransaction.objects.create(
        wallet=wallet,
        type=PracticeWalletTransaction.TxType.DEBIT,
        amount=amount,
        balance_after=wallet.balance,
        reference=str(reference)[:100],
        description=str(description)[:240],
    )
    _refill_if_low(wallet)
    wallet.refresh_from_db()
    return wallet


@transaction.atomic
def credit_practice_wallet(user, amount, *, reference='', description='') -> PracticeWallet:
    amount = Decimal(str(amount)).quantize(Decimal('0.01'))
    if amount <= 0:
        raise PracticeWalletError('Trade amount must be greater than zero.')
    wallet = get_practice_wallet(user, lock=True)
    wallet.balance += amount
    wallet.save(update_fields=['balance', 'updated_at'])
    PracticeWalletTransaction.objects.create(
        wallet=wallet,
        type=PracticeWalletTransaction.TxType.CREDIT,
        amount=amount,
        balance_after=wallet.balance,
        reference=str(reference)[:100],
        description=str(description)[:240],
    )
    return wallet


def practice_wallet_payload(user, *, transaction_limit=20) -> dict:
    wallet = get_practice_wallet(user)
    return {
        'balance': float(wallet.balance),
        'initialBalance': float(INITIAL_BALANCE),
        'refillThreshold': float(REFILL_THRESHOLD),
        'lastRefilledAt': (
            wallet.last_refilled_at.isoformat() if wallet.last_refilled_at else None
        ),
        'transactions': [
            {
                'id': str(row.id),
                'type': row.type,
                'amount': float(row.amount),
                'balanceAfter': float(row.balance_after),
                'reference': row.reference,
                'description': row.description,
                'createdAt': row.created_at.isoformat(),
            }
            for row in wallet.transactions.all()[:transaction_limit]
        ],
    }
