"""Admin panel aggregates, activity feed, and trade serializers."""

from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.db.models import Count, Q, Sum
from django.db.models.functions import TruncDate
from django.utils import timezone

from accounts.models import KycDocument, User
from engagement.models import Notification, SupportTicket
from finance.models import PaymentOrder, Wallet, WalletTransaction
from kyc.models import BankVerificationRequest, FnoEligibilityRequest, KYCRequest, KycProfile, VerificationAuditLog
from payments.models import PayoutRecord
from stocks.models import CommodityTrade, OptionTrade, PaperTrade


def money(value) -> str:
    return str(value if value is not None else Decimal('0'))


def user_summary() -> dict:
    pending_kyc = User.objects.filter(
        kyc_status__in=[User.KycStatus.PENDING, User.KycStatus.IN_PROGRESS, User.KycStatus.NOT_SUBMITTED]
    ).count()
    return {
        'total': User.objects.count(),
        'active': User.objects.filter(is_active=True, is_staff=False).count(),
        'blocked': User.objects.exclude(is_active=True).filter(is_staff=False).count(),
        'staff': User.objects.filter(is_staff=True).count(),
        'kycPending': pending_kyc,
        'kycVerified': User.objects.filter(
            kyc_status__in=[User.KycStatus.VERIFIED, User.KycStatus.COMPLETED]
        ).count(),
        'kycRejected': User.objects.filter(kyc_status=User.KycStatus.REJECTED).count(),
    }


def kyc_summary() -> dict:
    return {
        'panPending': KYCRequest.objects.filter(status=KYCRequest.Status.PENDING).count(),
        'panApproved': KYCRequest.objects.filter(status=KYCRequest.Status.APPROVED).count(),
        'panRejected': KYCRequest.objects.filter(status=KYCRequest.Status.REJECTED).count(),
        'bankPending': BankVerificationRequest.objects.filter(
            status=BankVerificationRequest.Status.PENDING
        ).count(),
        'bankApproved': BankVerificationRequest.objects.filter(
            status=BankVerificationRequest.Status.APPROVED
        ).count(),
        'bankRejected': BankVerificationRequest.objects.filter(
            status=BankVerificationRequest.Status.REJECTED
        ).count(),
        'selfiePending': KycProfile.objects.filter(
            selfie_status=KycProfile.SelfieStatus.COMPLETED
        ).count(),
        'selfieVerified': KycProfile.objects.filter(
            selfie_status=KycProfile.SelfieStatus.VERIFIED
        ).count(),
        'selfieRejected': KycProfile.objects.filter(
            selfie_status=KycProfile.SelfieStatus.REJECTED
        ).count(),
        'bankOverdue': BankVerificationRequest.objects.filter(
            status=BankVerificationRequest.Status.PENDING,
            review_due_at__lt=timezone.now(),
        ).count(),
        'documentsPending': KycDocument.objects.filter(status=KycDocument.Status.PENDING).count(),
        'profilesPending': KycProfile.objects.filter(overall_status=KycProfile.OverallStatus.PENDING).count(),
        'profilesVerified': KycProfile.objects.filter(overall_status=KycProfile.OverallStatus.VERIFIED).count(),
        'fnoPending': FnoEligibilityRequest.objects.filter(
            status=FnoEligibilityRequest.Status.PENDING
        ).count(),
        'fnoApproved': FnoEligibilityRequest.objects.filter(
            status=FnoEligibilityRequest.Status.APPROVED
        ).count(),
        'fnoRejected': FnoEligibilityRequest.objects.filter(
            status=FnoEligibilityRequest.Status.REJECTED
        ).count(),
    }


def money_summary() -> dict:
    wallet_totals = Wallet.objects.aggregate(total=Sum('balance'))
    payment_totals = PaymentOrder.objects.aggregate(
        total=Sum('amount'),
        paid=Sum('amount', filter=Q(status=PaymentOrder.Status.PAID)),
        failed=Sum('amount', filter=Q(status=PaymentOrder.Status.FAILED)),
    )
    return {
        'walletBalanceTotal': money(wallet_totals['total']),
        'paymentOrderTotal': money(payment_totals['total']),
        'paidTotal': money(payment_totals['paid']),
        'failedTotal': money(payment_totals['failed']),
        'pendingPayouts': PayoutRecord.objects.filter(
            status__in=[PayoutRecord.Status.SUBMITTED, PayoutRecord.Status.PROCESSING]
        ).count(),
    }


def revenue_chart(days: int = 14) -> list[dict]:
    since = timezone.now() - timedelta(days=days - 1)
    rows = (
        PaymentOrder.objects.filter(status=PaymentOrder.Status.PAID, paid_at__gte=since)
        .annotate(day=TruncDate('paid_at'))
        .values('day')
        .annotate(total=Sum('amount'), count=Count('id'))
        .order_by('day')
    )
    by_day = {row['day']: row for row in rows}
    chart = []
    for offset in range(days):
        day = (timezone.now() - timedelta(days=days - 1 - offset)).date()
        row = by_day.get(day)
        chart.append(
            {
                'date': day.isoformat(),
                'label': day.strftime('%d %b'),
                'revenue': money(row['total'] if row else 0),
                'orders': row['count'] if row else 0,
            }
        )
    return chart


def recent_users(limit: int = 8) -> list[dict]:
    return [
        {
            'id': str(u.id),
            'phone': u.phone,
            'name': u.name,
            'email': u.email,
            'kycStatus': u.kyc_status,
            'isActive': u.is_active,
            'dateJoined': u.date_joined.isoformat(),
        }
        for u in User.objects.order_by('-date_joined')[:limit]
    ]


def recent_activity(limit: int = 40) -> list[dict]:
    events: list[dict] = []

    for u in User.objects.order_by('-date_joined')[:20]:
        events.append(
            {
                'at': u.date_joined,
                'type': 'user_registered',
                'title': 'New user registered',
                'detail': f'{u.name or "Unnamed"} · {u.phone}',
                'userPhone': u.phone,
                'status': 'success',
            }
        )

    for p in PaymentOrder.objects.select_related('user').order_by('-created_at')[:30]:
        events.append(
            {
                'at': p.paid_at or p.created_at,
                'type': 'payment_received' if p.status == PaymentOrder.Status.PAID else 'payment_failed',
                'title': 'Payment received' if p.status == PaymentOrder.Status.PAID else 'Payment failed',
                'detail': f'{p.user.phone} · ₹{p.amount} · {p.gateway}',
                'userPhone': p.user.phone,
                'status': 'success' if p.status == PaymentOrder.Status.PAID else 'failed',
            }
        )

    for w in WalletTransaction.objects.select_related('wallet__user').order_by('-created_at')[:20]:
        if w.type == WalletTransaction.Type.DEPOSIT:
            events.append(
                {
                    'at': w.created_at,
                    'type': 'wallet_deposit',
                    'title': 'Wallet top-up',
                    'detail': f'{w.wallet.user.phone} · ₹{w.amount}',
                    'userPhone': w.wallet.user.phone,
                    'status': 'success',
                }
            )

    for r in KYCRequest.objects.select_related('user').order_by('-updated_at')[:20]:
        if r.status == KYCRequest.Status.APPROVED:
            events.append(
                {
                    'at': r.reviewed_at or r.updated_at,
                    'type': 'kyc_approved',
                    'title': 'PAN KYC approved',
                    'detail': f'{r.user.phone} · {r.full_name}',
                    'userPhone': r.user.phone,
                    'status': 'success',
                }
            )
        elif r.status == KYCRequest.Status.REJECTED:
            events.append(
                {
                    'at': r.reviewed_at or r.updated_at,
                    'type': 'kyc_rejected',
                    'title': 'PAN KYC rejected',
                    'detail': f'{r.user.phone}',
                    'userPhone': r.user.phone,
                    'status': 'failed',
                }
            )

    for r in BankVerificationRequest.objects.select_related('user').order_by('-updated_at')[:20]:
        if r.status == BankVerificationRequest.Status.APPROVED:
            events.append(
                {
                    'at': r.reviewed_at or r.submitted_at,
                    'type': 'kyc_approved',
                    'title': 'Bank & UPI approved',
                    'detail': f'{r.user.phone} · {r.upi_vpa or r.ifsc}',
                    'userPhone': r.user.phone,
                    'status': 'success',
                }
            )
        elif r.status == BankVerificationRequest.Status.REJECTED:
            events.append(
                {
                    'at': r.reviewed_at or r.submitted_at,
                    'type': 'kyc_rejected',
                    'title': 'Bank & UPI rejected',
                    'detail': f'{r.user.phone}',
                    'userPhone': r.user.phone,
                    'status': 'failed',
                }
            )

    events.sort(key=lambda item: item['at'], reverse=True)
    trimmed = events[:limit]
    for item in trimmed:
        item['at'] = item['at'].isoformat()
    return trimmed


def trade_summary(queryset, *, side_field='side', pnl_field=None) -> dict:
    buy_qs = queryset.filter(**{side_field: 'BUY'})
    sell_qs = queryset.filter(**{side_field: 'SELL'})
    total_pnl = Decimal('0')
    if pnl_field:
        agg = queryset.aggregate(total=Sum(pnl_field))
        total_pnl = agg['total'] or Decimal('0')
    return {
        'totalTrades': queryset.count(),
        'buyOrders': buy_qs.count(),
        'sellOrders': sell_qs.count(),
        'totalPnl': money(total_pnl),
    }


def serialize_paper_trade(row: PaperTrade) -> dict:
    return {
        'id': str(row.id),
        'userPhone': row.user.phone,
        'userName': row.user.name,
        'userEmail': row.user.email,
        'symbol': row.stock.symbol,
        'exchange': row.stock.exchange,
        'type': row.side,
        'quantity': row.quantity,
        'buyPrice': money(row.price) if row.side == PaperTrade.Side.BUY else '',
        'sellPrice': money(row.price) if row.side == PaperTrade.Side.SELL else '',
        'price': money(row.price),
        'avgCost': money(row.avg_cost) if row.avg_cost is not None else '',
        'pnl': money(row.realized_pnl) if row.realized_pnl is not None else '',
        'status': row.status,
        'tradeTime': row.created_at.isoformat(),
        'buyTime': row.created_at.isoformat() if row.side == PaperTrade.Side.BUY else '',
        'sellTime': row.created_at.isoformat() if row.side == PaperTrade.Side.SELL else '',
    }


def serialize_commodity_trade(row: CommodityTrade) -> dict:
    return {
        'id': str(row.id),
        'userPhone': row.user.phone,
        'userName': row.user.name,
        'userEmail': row.user.email,
        'commodity': row.commodity_id,
        'contract': row.commodity_id,
        'exchange': 'MCX',
        'type': row.side,
        'lots': row.quantity,
        'quantity': row.quantity,
        'buyPrice': money(row.price_usd) if row.side == CommodityTrade.Side.BUY else '',
        'sellPrice': money(row.price_usd) if row.side == CommodityTrade.Side.SELL else '',
        'priceUsd': money(row.price_usd),
        'amountInr': money(row.amount_inr),
        'pnl': '',
        'status': row.status,
        'expiry': '',
        'tradeTime': row.created_at.isoformat(),
        'buyTime': row.created_at.isoformat() if row.side == CommodityTrade.Side.BUY else '',
        'sellTime': row.created_at.isoformat() if row.side == CommodityTrade.Side.SELL else '',
    }


def serialize_option_trade(row: OptionTrade, *, segment: str) -> dict:
    return {
        'id': str(row.id),
        'userPhone': row.user.phone,
        'userName': row.user.name,
        'userEmail': row.user.email,
        'underlying': row.underlying,
        'contract': f'{row.underlying} {row.strike} {row.option_type}',
        'exchange': 'NSE' if row.asset_class == OptionTrade.AssetClass.EQUITY_FNO else 'MCX',
        'segment': segment,
        'optionType': row.option_type,
        'type': row.side,
        'lots': row.quantity,
        'quantity': row.quantity * row.lot_size,
        'lotSize': row.lot_size,
        'strike': str(row.strike),
        'premium': money(row.premium),
        'buyPrice': money(row.premium) if row.side == OptionTrade.Side.BUY else '',
        'sellPrice': money(row.premium) if row.side == OptionTrade.Side.SELL else '',
        'amountInr': money(row.amount_inr),
        'pnl': money(row.realized_pnl_inr) if row.realized_pnl_inr is not None else '',
        'status': row.status,
        'expiry': row.expiry.isoformat(),
        'tradeTime': row.created_at.isoformat(),
        'buyTime': row.created_at.isoformat() if row.side == OptionTrade.Side.BUY else '',
        'sellTime': row.created_at.isoformat() if row.side == OptionTrade.Side.SELL else '',
    }
