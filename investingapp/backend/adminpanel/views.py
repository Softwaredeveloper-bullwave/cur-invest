from datetime import datetime, timedelta
from decimal import Decimal

from django.contrib.auth import authenticate
from django.db.models import Q, Sum
from django.utils.dateparse import parse_date, parse_datetime
from django.utils import timezone
from rest_framework.permissions import AllowAny, IsAdminUser, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .auth import admin_panel_authentication_classes
from accounts.models import KycDocument, User
from engagement.models import SupportTicket
from finance.models import PaymentOrder, Wallet
from kyc.bank_manual_service import (
    ManualBankReviewError,
    approve_bank_review,
    reject_bank_review,
    serialize_bank_request,
)
from kyc.identity_review_service import (
    IdentityReviewError,
    approve_manual_upi,
    final_kyc_approve,
    ready_for_final_kyc_approval,
    reject_manual_upi,
    serialize_identity_review,
)
from kyc.manual_service import ManualKycError, approve_kyc_request, reject_kyc_request, serialize_request
from kyc.masking import mask_account_number, mask_pan
from kyc.models import BankVerificationRequest, KYCRequest, KycProfile, VerificationAuditLog
from kyc.selfie_service import (
    SelfieError,
    approve_selfie,
    reject_selfie,
    serialize_selfie_review,
)
from payments.models import PayoutRecord
from stocks.models import CommodityTrade, OptionTrade, PaperTrade

from core.error_reporting import safe_context, sanitize_text
from .models import AdminActionAudit, AdminBroadcast, AdminNotification, ApplicationErrorEvent
from . import reporting
from .broadcast_service import send_broadcast, serialize_broadcast
from .kyc_display import admin_kyc_status, admin_pan_status
from .notifications_service import notification_summary, serialize_notification, sync_admin_notifications
from .support_service import (
    admin_reopen_ticket,
    admin_reply_to_ticket,
    admin_resolve_ticket,
    serialize_ticket,
)


def _client_ip(request):
    forwarded = request.META.get('HTTP_X_FORWARDED_FOR', '')
    return forwarded.split(',')[0].strip() if forwarded else request.META.get('REMOTE_ADDR')


def _audit(request, *, action: str, target_type: str, target_id, summary: str = '', metadata=None):
    audit_metadata = dict(metadata or {})
    audit_metadata.setdefault('userAgent', str(request.META.get('HTTP_USER_AGENT') or '')[:300])
    AdminActionAudit.objects.create(
        actor=request.user,
        action=action,
        target_type=target_type,
        target_id=str(target_id),
        summary=summary[:500],
        metadata=audit_metadata,
        ip_address=_client_ip(request),
    )


def _money(value):
    return str(value if value is not None else Decimal('0'))


class AdminPanelAPIView(APIView):
    authentication_classes = admin_panel_authentication_classes()
    permission_classes = [IsAuthenticated, IsAdminUser]


class AdminLoginView(APIView):
    permission_classes = [AllowAny]
    authentication_classes = []

    def post(self, request):
        phone = str(request.data.get('phone') or '').strip()
        password = str(request.data.get('password') or '')
        try:
            check_rate_limit(
                f'admin-login:{_client_ip(request) or "unknown"}:{phone}',
                limit=5,
                window_seconds=300,
            )
        except RateLimitExceeded as exc:
            return Response({'detail': str(exc)}, status=429)
        user = authenticate(request, username=phone, password=password)
        if not user or not user.is_active or not user.is_staff:
            return Response({'detail': 'Invalid admin credentials.'}, status=401)
        refresh = RefreshToken.for_user(user)
        refresh.set_exp(lifetime=timedelta(hours=8))
        access = refresh.access_token
        access.set_exp(lifetime=timedelta(minutes=30))
        return Response(
            {
                'access': str(access),
                'refresh': str(refresh),
                'admin': {
                    'id': str(user.id),
                    'phone': user.phone,
                    'name': user.name,
                    'email': user.email,
                    'isSuperuser': user.is_superuser,
                },
            }
        )


class AdminMeView(AdminPanelAPIView):
    def get(self, request):
        return Response(
            {
                'id': str(request.user.id),
                'phone': request.user.phone,
                'name': request.user.name,
                'email': request.user.email,
                'isSuperuser': request.user.is_superuser,
            }
        )


class DashboardView(AdminPanelAPIView):
    def get(self, request):
        return Response(
            {
                'users': reporting.user_summary(),
                'reviews': reporting.kyc_summary(),
                'money': reporting.money_summary(),
                'support': {
                    'openTickets': SupportTicket.objects.exclude(
                        status=SupportTicket.Status.RESOLVED
                    ).count(),
                },
                'revenueChart': reporting.revenue_chart(),
                'recentUsers': reporting.recent_users(),
                'recentActivity': reporting.recent_activity(),
                'trading': {
                    'stocks': reporting.trade_summary(
                        PaperTrade.objects.all(),
                        pnl_field='realized_pnl',
                    ),
                    'commodities': reporting.trade_summary(CommodityTrade.objects.all()),
                    'futures': reporting.trade_summary(
                        OptionTrade.objects.filter(asset_class=OptionTrade.AssetClass.EQUITY_FNO),
                        pnl_field='realized_pnl_inr',
                    ),
                    'options': reporting.trade_summary(
                        OptionTrade.objects.all(),
                        pnl_field='realized_pnl_inr',
                    ),
                },
            }
        )


class UserListView(AdminPanelAPIView):
    def get(self, request):
        search = str(request.query_params.get('search') or '').strip()
        rows = User.objects.order_by('-date_joined')
        if search:
            rows = rows.filter(Q(phone__icontains=search) | Q(name__icontains=search) | Q(email__icontains=search))
        data = [
            {
                'id': str(row.id),
                'phone': row.phone,
                'name': row.name,
                'email': row.email,
                'kycStatus': admin_kyc_status(row, getattr(row, 'kyc_profile', None)),
                'panStatus': admin_pan_status(row, getattr(row, 'kyc_profile', None)),
                'fnoStatus': row.fno_status,
                'isActive': row.is_active,
                'isStaff': row.is_staff,
                'dateJoined': row.date_joined.isoformat(),
                'walletBalance': _money(getattr(getattr(row, 'wallet', None), 'balance', 0)),
            }
            for row in rows.select_related('wallet', 'kyc_profile')[:200]
        ]
        return Response({'results': data, 'count': len(data), 'summary': reporting.user_summary()})


def _serialize_user_detail(user: User) -> dict:
    profile = getattr(user, 'kyc_profile', None)
    return {
        'id': str(user.id),
        'phone': user.phone,
        'name': user.name,
        'email': user.email,
        'emailVerified': user.email_verified,
        'kycStatus': admin_kyc_status(user, profile),
        'panStatus': admin_pan_status(user, profile),
        'fnoStatus': user.fno_status,
        'isActive': user.is_active,
        'isStaff': user.is_staff,
        'dateJoined': user.date_joined.isoformat(),
        'city': user.city,
        'dateOfBirth': user.date_of_birth.isoformat() if user.date_of_birth else None,
        'walletBalance': _money(getattr(getattr(user, 'wallet', None), 'balance', 0)),
        'overallKycStatus': getattr(profile, 'overall_status', ''),
        'aadhaarStatus': getattr(profile, 'aadhaar_status', ''),
        'selfieStatus': getattr(profile, 'selfie_status', ''),
        'bankStatus': getattr(profile, 'bank_status', ''),
        'upiStatus': getattr(profile, 'upi_status', ''),
        'upiVpa': getattr(profile, 'upi_vpa', ''),
    }


class UserDetailView(AdminPanelAPIView):
    def get(self, request, user_id):
        try:
            user = User.objects.select_related('wallet', 'kyc_profile').get(pk=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)
        return Response(_serialize_user_detail(user))

    def patch(self, request, user_id):
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)
        if user.is_superuser and str(request.user.id) != str(user.id):
            return Response({'detail': 'Cannot edit another superuser.'}, status=403)
        allowed = ('name', 'email', 'city', 'kyc_status', 'pan_status', 'fno_status')
        updates = []
        for field in allowed:
            if field in request.data:
                setattr(user, field, request.data[field])
                updates.append(field)
        if updates:
            user.save(update_fields=updates + ['updated_at'] if hasattr(user, 'updated_at') else updates)
        _audit(request, action='user_update', target_type='User', target_id=user.id, summary=f'Updated {", ".join(updates)}')
        return Response(_serialize_user_detail(User.objects.select_related('wallet', 'kyc_profile').get(pk=user.id)))


class UserBlockView(AdminPanelAPIView):
    def post(self, request, user_id, action):
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)
        if user.is_staff:
            return Response({'detail': 'Cannot block staff accounts.'}, status=400)
        if action == 'block':
            user.is_active = False
            summary = f'Blocked user {user.phone}'
        elif action == 'unblock':
            user.is_active = True
            summary = f'Unblocked user {user.phone}'
        else:
            return Response({'detail': 'Unsupported action.'}, status=400)
        user.save(update_fields=['is_active'])
        _audit(request, action=f'user_{action}', target_type='User', target_id=user.id, summary=summary)
        return Response({'success': True, 'isActive': user.is_active})


class UserDeleteView(AdminPanelAPIView):
    def delete(self, request, user_id):
        try:
            user = User.objects.get(pk=user_id)
        except User.DoesNotExist:
            return Response({'detail': 'User not found.'}, status=404)
        if user.is_staff:
            return Response({'detail': 'Cannot delete staff accounts.'}, status=400)
        phone = user.phone
        user.delete()
        _audit(request, action='user_delete', target_type='User', target_id=user_id, summary=f'Deleted user {phone}')
        return Response({'success': True})


def _serialize_kyc_profile_row(row: KycProfile) -> dict:
    return {
        'userId': str(row.user_id),
        'phone': row.user.phone,
        'name': row.user.name,
        'email': row.user.email,
        'overallStatus': row.overall_status,
        'panStatus': row.pan_status,
        'panNumber': mask_pan(row.pan_number) if row.pan_number else '',
        'panName': row.pan_name,
        'aadhaarStatus': row.aadhaar_status,
        'aadhaarLast4': row.aadhaar_last4,
        'aadhaarName': row.aadhaar_name,
        'bankStatus': row.bank_status,
        'accountNumber': mask_account_number(row.bank_account_number),
        'ifsc': row.bank_ifsc,
        'accountHolderName': row.account_holder_name,
        'bankName': row.bank_name,
        'upiStatus': row.upi_status,
        'upiVpa': row.upi_vpa,
        'selfieStatus': row.selfie_status,
        'selfieUploadedAt': row.selfie_uploaded_at.isoformat() if row.selfie_uploaded_at else None,
        'readyForFinalApproval': ready_for_final_kyc_approval(row),
        'finalKycApprovedAt': row.final_kyc_approved_at.isoformat() if row.final_kyc_approved_at else None,
        'updatedAt': row.updated_at.isoformat(),
    }


class KycOverviewView(AdminPanelAPIView):
    def get(self, request):
        status_filter = str(request.query_params.get('status') or '').upper()
        pan_rows = KYCRequest.objects.select_related('user').prefetch_related('images').order_by('-created_at')
        if status_filter and status_filter != 'ALL':
            pan_rows = pan_rows.filter(status=status_filter)
        pan_results = []
        for row in pan_rows[:200]:
            item = serialize_request(row, request)
            item['user'] = {'phone': row.user.phone, 'name': row.user.name, 'email': row.user.email}
            pan_results.append(item)
        bank_status = str(request.query_params.get('bankStatus') or 'pending').lower()
        bank_rows = BankVerificationRequest.objects.select_related('user').order_by('-submitted_at')
        if bank_status != 'all':
            bank_rows = bank_rows.filter(status=bank_status)
        selfie_status = str(request.query_params.get('selfieStatus') or 'completed').lower()
        selfie_rows = KycProfile.objects.select_related('user', 'selfie_reviewed_by').exclude(
            selfie_status=KycProfile.SelfieStatus.PENDING
        ).order_by('-selfie_uploaded_at')
        if selfie_status != 'all':
            selfie_rows = selfie_rows.filter(selfie_status=selfie_status)
        identity_rows = [
            serialize_identity_review(row, request)
            for row in KycProfile.objects.select_related('user').filter(
                bank_status=KycProfile.VerificationStatus.VERIFIED,
            ).order_by('-updated_at')[:300]
            if row.upi_status == KycProfile.VerificationStatus.PENDING
            or row.selfie_status == KycProfile.SelfieStatus.COMPLETED
            or ready_for_final_kyc_approval(row)
        ][:200]
        profiles = [
            _serialize_kyc_profile_row(row)
            for row in KycProfile.objects.select_related('user').order_by('-updated_at')[:200]
        ]
        return Response(
            {
                'summary': reporting.kyc_summary(),
                'panRequests': pan_results,
                'bankRequests': [
                    serialize_bank_request(row, reveal_account=True) for row in bank_rows[:200]
                ],
                'selfieRequests': [
                    serialize_selfie_review(row, request) for row in selfie_rows[:200]
                ],
                'identityReviews': identity_rows,
                'profiles': profiles,
            }
        )


class TradingReportView(AdminPanelAPIView):
    segment = 'stocks'

    def get_queryset(self):
        if self.segment == 'stocks':
            return PaperTrade.objects.select_related('user', 'stock').order_by('-created_at')
        if self.segment == 'commodities':
            return CommodityTrade.objects.select_related('user').order_by('-created_at')
        if self.segment == 'futures':
            return OptionTrade.objects.filter(
                asset_class=OptionTrade.AssetClass.EQUITY_FNO,
            ).select_related('user').order_by('-created_at')
        return OptionTrade.objects.filter(
            option_type__in=('CE', 'PE'),
        ).select_related('user').order_by('-created_at')

    def serialize_rows(self, rows):
        if self.segment == 'stocks':
            return [reporting.serialize_paper_trade(row) for row in rows]
        if self.segment == 'commodities':
            return [reporting.serialize_commodity_trade(row) for row in rows]
        label = 'futures' if self.segment == 'futures' else 'options'
        return [reporting.serialize_option_trade(row, segment=label) for row in rows]

    def get_summary(self):
        qs = self.get_queryset()
        pnl_field = 'realized_pnl' if self.segment == 'stocks' else (
            'realized_pnl_inr' if self.segment in ('futures', 'options') else None
        )
        return reporting.trade_summary(qs, pnl_field=pnl_field)

    def get(self, request):
        rows = self.get_queryset()[:300]
        return Response({'summary': self.get_summary(), 'results': self.serialize_rows(rows), 'count': len(rows)})


class StocksReportView(TradingReportView):
    segment = 'stocks'


class CommoditiesReportView(TradingReportView):
    segment = 'commodities'


class FuturesReportView(TradingReportView):
    segment = 'futures'


class OptionsReportView(TradingReportView):
    segment = 'options'


class KycProfileListView(AdminPanelAPIView):
    def get(self, request):
        status_filter = str(request.query_params.get('status') or '').lower()
        rows = KycProfile.objects.select_related('user').order_by('-updated_at')
        if status_filter:
            rows = rows.filter(overall_status=status_filter)
        data = [_serialize_kyc_profile_row(row) for row in rows[:200]]
        return Response({'results': data, 'count': len(data)})


class PanReviewListView(AdminPanelAPIView):
    def get(self, request):
        status_filter = str(request.query_params.get('status') or KYCRequest.Status.PENDING).upper()
        rows = KYCRequest.objects.select_related('user', 'reviewed_by').prefetch_related('images')
        if status_filter != 'ALL':
            rows = rows.filter(status=status_filter)
        results = []
        for row in rows[:200]:
            item = serialize_request(row, request)
            item['user'] = {
                'id': str(row.user_id),
                'phone': row.user.phone,
                'name': row.user.name,
                'email': row.user.email,
            }
            results.append(item)
        _audit(
            request,
            action='pan_queue_view',
            target_type='KYCRequest',
            target_id='list',
            summary=f'Viewed {len(results)} PAN review records.',
        )
        return Response({'results': results, 'count': len(results)})


class PanReviewDecisionView(AdminPanelAPIView):
    def post(self, request, pk, decision):
        try:
            row = KYCRequest.objects.select_related('user').get(pk=pk)
            if decision == 'approve':
                row = approve_kyc_request(row, request.user)
                summary = 'PAN/KYC request approved.'
            elif decision == 'reject':
                reason = request.data.get('reason') or request.data.get('rejectionReason') or ''
                row = reject_kyc_request(row, request.user, reason)
                summary = f'PAN/KYC request rejected: {reason}'
            else:
                return Response({'detail': 'Unsupported decision.'}, status=400)
        except KYCRequest.DoesNotExist:
            return Response({'detail': 'PAN/KYC request not found.'}, status=404)
        except ManualKycError as exc:
            return Response({'detail': str(exc)}, status=400)
        _audit(
            request,
            action=f'pan_{decision}',
            target_type='KYCRequest',
            target_id=row.id,
            summary=summary,
        )
        return Response({'success': True, 'request': serialize_request(row, request)})


class BankReviewListView(AdminPanelAPIView):
    def get(self, request):
        status_filter = str(
            request.query_params.get('status') or BankVerificationRequest.Status.PENDING
        ).lower()
        rows = BankVerificationRequest.objects.select_related('user', 'reviewed_by')
        if status_filter != 'all':
            rows = rows.filter(status=status_filter)
        data = [serialize_bank_request(row, reveal_account=True) for row in rows[:200]]
        _audit(
            request,
            action='bank_queue_view',
            target_type='BankVerificationRequest',
            target_id='list',
            summary=f'Viewed {len(data)} bank review records with account details.',
        )
        return Response({'results': data, 'count': len(data)})


class BankReviewDecisionView(AdminPanelAPIView):
    def post(self, request, pk, decision):
        try:
            row = BankVerificationRequest.objects.select_related('user').get(pk=pk)
            if decision == 'approve':
                note = request.data.get('note') or ''
                row = approve_bank_review(row, request.user, note=note)
                summary = 'Bank account manually approved.'
            elif decision == 'reject':
                reason = request.data.get('reason') or ''
                row = reject_bank_review(row, request.user, reason=reason)
                summary = f'Bank account rejected: {reason}'
            else:
                return Response({'detail': 'Unsupported decision.'}, status=400)
        except BankVerificationRequest.DoesNotExist:
            return Response({'detail': 'Bank review request not found.'}, status=404)
        except ManualBankReviewError as exc:
            return Response({'detail': str(exc)}, status=400)
        _audit(
            request,
            action=f'bank_{decision}',
            target_type='BankVerificationRequest',
            target_id=row.id,
            summary=summary,
            metadata={'userId': str(row.user_id), 'ifsc': row.ifsc},
        )
        return Response({'success': True, 'request': serialize_bank_request(row, reveal_account=True)})


class SelfieReviewListView(AdminPanelAPIView):
    def get(self, request):
        status_filter = str(
            request.query_params.get('status') or KycProfile.SelfieStatus.COMPLETED
        ).lower()
        rows = KycProfile.objects.select_related('user', 'selfie_reviewed_by').exclude(
            selfie_status=KycProfile.SelfieStatus.PENDING
        ).order_by('-selfie_uploaded_at')
        if status_filter != 'all':
            rows = rows.filter(selfie_status=status_filter)
        data = [serialize_selfie_review(row, request) for row in rows[:200]]
        _audit(
            request,
            action='selfie_queue_view',
            target_type='KycProfile',
            target_id='list',
            summary=f'Viewed {len(data)} selfie review records.',
        )
        return Response({'results': data, 'count': len(data)})


class SelfieReviewDecisionView(AdminPanelAPIView):
    def post(self, request, user_id, decision):
        try:
            profile = KycProfile.objects.select_related('user').get(user_id=user_id)
        except KycProfile.DoesNotExist:
            return Response({'detail': 'KYC profile not found.'}, status=404)
        try:
            if decision == 'approve':
                note = request.data.get('note') or ''
                profile = approve_selfie(profile, request.user, note=note)
                summary = 'Selfie manually approved.'
            elif decision == 'reject':
                reason = request.data.get('reason') or ''
                profile = reject_selfie(profile, request.user, reason=reason)
                summary = f'Selfie rejected: {reason}'
            else:
                return Response({'detail': 'Unsupported decision.'}, status=400)
        except SelfieError as exc:
            return Response({'detail': str(exc)}, status=400)
        _audit(
            request,
            action=f'selfie_{decision}',
            target_type='KycProfile',
            target_id=user_id,
            summary=summary,
            metadata={'userId': str(user_id)},
        )
        return Response({'success': True, 'profile': serialize_selfie_review(profile, request)})


class IdentityUpiDecisionView(AdminPanelAPIView):
    def post(self, request, user_id, decision):
        try:
            profile = KycProfile.objects.select_related('user').get(user_id=user_id)
        except KycProfile.DoesNotExist:
            return Response({'detail': 'KYC profile not found.'}, status=404)
        note = str(request.data.get('note') or request.data.get('reason') or '').strip()
        try:
            if decision == 'approve':
                profile = approve_manual_upi(profile, request.user, note=note)
                summary = 'Manual UPI approved.'
            elif decision == 'reject':
                reason = note or str(request.data.get('reason') or '').strip()
                if len(reason) < 3:
                    return Response({'detail': 'Enter a rejection reason.'}, status=400)
                profile = reject_manual_upi(profile, request.user, reason=reason)
                summary = f'Manual UPI rejected: {reason}'
            else:
                return Response({'detail': 'Unsupported decision.'}, status=400)
        except IdentityReviewError as exc:
            return Response({'detail': str(exc)}, status=400)
        _audit(
            request,
            action=f'upi_{decision}',
            target_type='KycProfile',
            target_id=user_id,
            summary=summary,
        )
        return Response({'success': True, 'profile': serialize_identity_review(profile, request)})


class FinalKycDecisionView(AdminPanelAPIView):
    def post(self, request, user_id, decision):
        try:
            profile = KycProfile.objects.select_related('user').get(user_id=user_id)
        except KycProfile.DoesNotExist:
            return Response({'detail': 'KYC profile not found.'}, status=404)
        note = str(request.data.get('note') or request.data.get('reason') or '').strip()
        if decision == 'approve':
            try:
                profile = final_kyc_approve(profile, request.user, note=note)
            except IdentityReviewError as exc:
                return Response({'detail': str(exc)}, status=400)
            summary = note or 'Final KYC approved.'
        else:
            return Response({'detail': 'Unsupported decision.'}, status=400)
        _audit(
            request,
            action='final_kyc_approve',
            target_type='KycProfile',
            target_id=user_id,
            summary=summary,
        )
        return Response({'success': True, 'profile': serialize_identity_review(profile, request)})


class AadhaarDecisionView(AdminPanelAPIView):
    def post(self, request, user_id, decision):
        try:
            profile = KycProfile.objects.select_related('user').get(user_id=user_id)
        except KycProfile.DoesNotExist:
            return Response({'detail': 'KYC profile not found.'}, status=404)
        note = str(request.data.get('reason') or request.data.get('note') or '').strip()
        if decision == 'approve':
            profile.aadhaar_status = KycProfile.VerificationStatus.VERIFIED
            profile.aadhaar_verified_at = timezone.now()
            profile.aadhaar_failure_reason = ''
        elif decision == 'reject':
            if len(note) < 3:
                return Response({'detail': 'Enter a rejection reason.'}, status=400)
            profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
            profile.aadhaar_verified_at = None
            profile.aadhaar_failure_reason = note[:280]
        else:
            return Response({'detail': 'Unsupported decision.'}, status=400)
        profile.save(update_fields=['aadhaar_status', 'aadhaar_verified_at', 'aadhaar_failure_reason', 'updated_at'])
        if decision == 'approve':
            from kyc.service import _update_overall_status

            _update_overall_status(profile)
        else:
            profile.overall_status = KycProfile.OverallStatus.REJECTED
            profile.verified_at = None
            profile.save(update_fields=['overall_status', 'verified_at', 'updated_at'])
            profile.user.kyc_status = User.KycStatus.REJECTED
            profile.user.save(update_fields=['kyc_status'])
        VerificationAuditLog.objects.create(
            user=profile.user,
            step=VerificationAuditLog.Step.AADHAAR,
            status=(
                VerificationAuditLog.Status.SUCCESS
                if decision == 'approve'
                else VerificationAuditLog.Status.FAILED
            ),
            message=note or 'Verified manually by admin.',
            response_meta={'provider': 'manual_admin', 'reviewer': str(request.user.id)},
        )
        _audit(
            request,
            action=f'aadhaar_{decision}',
            target_type='KycProfile',
            target_id=profile.user_id,
            summary=note or 'Aadhaar manually approved.',
        )
        return Response({'success': True, 'aadhaarStatus': profile.aadhaar_status})


class FinanceReportView(AdminPanelAPIView):
    """Read-only money/reporting API. Balance mutation is intentionally not generic CRUD."""

    def get(self, request):
        wallets = [
            {
                'userId': str(row.user_id),
                'phone': row.user.phone,
                'name': row.user.name,
                'balance': _money(row.balance),
                'updatedAt': row.updated_at.isoformat(),
            }
            for row in Wallet.objects.select_related('user').order_by('-updated_at')[:200]
        ]
        payments = [
            {
                'id': str(row.id),
                'phone': row.user.phone,
                'gateway': row.gateway,
                'orderId': row.order_id,
                'paymentId': row.payment_id,
                'amount': _money(row.amount),
                'currency': row.currency,
                'status': row.status,
                'createdAt': row.created_at.isoformat(),
                'paidAt': row.paid_at.isoformat() if row.paid_at else None,
            }
            for row in PaymentOrder.objects.select_related('user')[:200]
        ]
        payouts = [
            {
                'id': str(row.id),
                'phone': row.user.phone,
                'transferId': row.transfer_id,
                'referenceId': row.reference_id,
                'amount': _money(row.amount),
                'status': row.status,
                'failureReason': row.failure_reason,
                'createdAt': row.created_at.isoformat(),
            }
            for row in PayoutRecord.objects.select_related('user')[:200]
        ]
        return Response({'wallets': wallets, 'payments': payments, 'payouts': payouts})


class AuditLogView(AdminPanelAPIView):
    def get(self, request):
        rows = AdminActionAudit.objects.select_related('actor')[:300]
        return Response(
            {
                'results': [
                    {
                        'id': str(row.id),
                        'actor': row.actor.phone if row.actor else '',
                        'action': row.action,
                        'targetType': row.target_type,
                        'targetId': row.target_id,
                        'summary': row.summary,
                        'metadata': row.metadata,
                        'ipAddress': row.ip_address,
                        'createdAt': row.created_at.isoformat(),
                    }
                    for row in rows
                ]
            }
        )


def _serialize_error(row: ApplicationErrorEvent, *, include_context=False):
    data = {
        'id': str(row.id),
        'source': row.source,
        'severity': row.severity,
        'status': row.status,
        'loggerName': row.logger_name,
        'message': row.message,
        'exceptionType': row.exception_type,
        'location': row.location,
        'method': row.method,
        'statusCode': row.status_code,
        'userId': str(row.user_id) if row.user_id else None,
        'userPhone': row.user.phone if row.user else '',
        'occurrenceCount': row.occurrence_count,
        'firstSeenAt': row.first_seen_at.isoformat(),
        'lastSeenAt': row.last_seen_at.isoformat(),
        'resolvedAt': row.resolved_at.isoformat() if row.resolved_at else None,
        'resolvedBy': row.resolved_by.phone if row.resolved_by else '',
    }
    if include_context:
        data['context'] = safe_context(row.context)
    return data


class ErrorLogView(AdminPanelAPIView):
    def get(self, request):
        rows = ApplicationErrorEvent.objects.select_related('user', 'resolved_by')
        source = str(request.query_params.get('source') or '').lower()
        severity = str(request.query_params.get('severity') or '').lower()
        event_status = str(request.query_params.get('status') or '').lower()
        search = str(request.query_params.get('search') or '').strip()
        since_value = str(request.query_params.get('since') or '').strip()
        if source:
            rows = rows.filter(source=source)
        if severity:
            rows = rows.filter(severity=severity)
        if event_status:
            rows = rows.filter(status=event_status)
        if search:
            rows = rows.filter(
                Q(message__icontains=search)
                | Q(exception_type__icontains=search)
                | Q(location__icontains=search)
                | Q(user__phone__icontains=search)
            )
        if since_value:
            since = parse_datetime(since_value)
            if since is None:
                parsed_day = parse_date(since_value)
                since = timezone.make_aware(
                    datetime.combine(parsed_day, datetime.min.time())
                ) if parsed_day else None
            if since:
                rows = rows.filter(last_seen_at__gte=since)
        try:
            limit = min(max(int(request.query_params.get('limit') or 200), 1), 500)
        except (TypeError, ValueError):
            limit = 200

        now = timezone.now()
        day_ago = now - timedelta(hours=24)
        week_ago = now - timedelta(days=7)
        application_rows = ApplicationErrorEvent.objects.all()
        failed_verifications = VerificationAuditLog.objects.filter(
            status=VerificationAuditLog.Status.FAILED
        )
        failed_payments = PaymentOrder.objects.filter(status=PaymentOrder.Status.FAILED)
        failed_payouts = PayoutRecord.objects.filter(status=PayoutRecord.Status.FAILED)
        return Response(
            {
                'summary': {
                    'open': application_rows.filter(status=ApplicationErrorEvent.Status.OPEN).count(),
                    'critical': application_rows.filter(
                        status=ApplicationErrorEvent.Status.OPEN,
                        severity=ApplicationErrorEvent.Severity.CRITICAL,
                    ).count(),
                    'last24Hours': application_rows.filter(last_seen_at__gte=day_ago).count(),
                    'last7Days': application_rows.filter(last_seen_at__gte=week_ago).count(),
                    'failedKyc': failed_verifications.count(),
                    'failedPayments': failed_payments.count(),
                    'failedPayouts': failed_payouts.count(),
                },
                'results': [_serialize_error(row) for row in rows[:limit]],
                'kycFailures': [
                    {
                        'id': str(row.id),
                        'source': 'kyc',
                        'step': row.step,
                        'message': sanitize_text(row.message),
                        'userId': str(row.user_id),
                        'userPhone': row.user.phone,
                        'createdAt': row.created_at.isoformat(),
                    }
                    for row in failed_verifications.select_related('user')[:100]
                ],
                'paymentFailures': [
                    {
                        'id': str(row.id),
                        'source': 'payment',
                        'gateway': row.gateway,
                        'message': f'Payment order failed ({row.gateway})',
                        'amount': _money(row.amount),
                        'userId': str(row.user_id),
                        'userPhone': row.user.phone,
                        'createdAt': row.created_at.isoformat(),
                    }
                    for row in failed_payments.select_related('user')[:100]
                ],
                'payoutFailures': [
                    {
                        'id': str(row.id),
                        'source': 'payout',
                        'message': sanitize_text(row.failure_reason or 'Payout failed'),
                        'amount': _money(row.amount),
                        'userId': str(row.user_id),
                        'userPhone': row.user.phone,
                        'createdAt': row.created_at.isoformat(),
                    }
                    for row in failed_payouts.select_related('user')[:100]
                ],
            }
        )


class ErrorDetailView(AdminPanelAPIView):
    def get(self, request, pk):
        try:
            row = ApplicationErrorEvent.objects.select_related('user', 'resolved_by').get(pk=pk)
        except ApplicationErrorEvent.DoesNotExist:
            return Response({'detail': 'Error event not found.'}, status=404)
        return Response(_serialize_error(row, include_context=True))

    def post(self, request, pk, action):
        try:
            row = ApplicationErrorEvent.objects.get(pk=pk)
        except ApplicationErrorEvent.DoesNotExist:
            return Response({'detail': 'Error event not found.'}, status=404)
        if action == 'resolve':
            row.status = ApplicationErrorEvent.Status.RESOLVED
            row.resolved_by = request.user
            row.resolved_at = timezone.now()
        elif action == 'reopen':
            row.status = ApplicationErrorEvent.Status.OPEN
            row.resolved_by = None
            row.resolved_at = None
        else:
            return Response({'detail': 'Unsupported action.'}, status=400)
        row.save(update_fields=['status', 'resolved_by', 'resolved_at'])
        _audit(
            request,
            action=f'error_{action}',
            target_type='ApplicationErrorEvent',
            target_id=row.id,
            summary=f'{action.title()}d application error.',
        )
        return Response(_serialize_error(row, include_context=True))


class ErrorBulkDeleteView(AdminPanelAPIView):
    def post(self, request):
        if not request.user.is_superuser:
            return Response({'detail': 'Only a superuser can delete error records.'}, status=403)
        ids = request.data.get('ids')
        if not isinstance(ids, list) or not ids:
            return Response({'detail': 'ids must be a non-empty list.'}, status=400)
        rows = ApplicationErrorEvent.objects.filter(
            id__in=ids[:200],
            status=ApplicationErrorEvent.Status.RESOLVED,
        )
        deleted_ids = [str(value) for value in rows.values_list('id', flat=True)]
        rows.delete()
        _audit(
            request,
            action='error_bulk_delete',
            target_type='ApplicationErrorEvent',
            target_id='bulk',
            summary=f'Deleted {len(deleted_ids)} resolved error records.',
        )
        return Response({'deleted': len(deleted_ids), 'ids': deleted_ids})


class AdminNotificationListView(AdminPanelAPIView):
    def get(self, request):
        payload = notification_summary()
        return Response(payload)


class AdminNotificationReadView(AdminPanelAPIView):
    def post(self, request, pk, action):
        try:
            row = AdminNotification.objects.get(pk=pk)
        except AdminNotification.DoesNotExist:
            return Response({'detail': 'Notification not found.'}, status=404)
        if action == 'read':
            row.is_read = True
            row.read_at = timezone.now()
            row.save(update_fields=['is_read', 'read_at'])
        elif action == 'unread':
            row.is_read = False
            row.read_at = None
            row.save(update_fields=['is_read', 'read_at'])
        else:
            return Response({'detail': 'Unsupported action.'}, status=400)
        return Response(serialize_notification(row))


class AdminNotificationReadAllView(AdminPanelAPIView):
    def post(self, request):
        AdminNotification.objects.filter(is_read=False).update(
            is_read=True,
            read_at=timezone.now(),
        )
        return Response({'success': True})


class AdminSupportTicketListView(AdminPanelAPIView):
    def get(self, request):
        status = str(request.query_params.get('status') or '').strip()
        search = str(request.query_params.get('search') or '').strip()
        rows = SupportTicket.objects.select_related('user', 'resolved_by').prefetch_related('messages')
        if status:
            rows = rows.filter(status=status)
        if search:
            rows = rows.filter(
                Q(subject__icontains=search)
                | Q(user__phone__icontains=search)
                | Q(user__name__icontains=search)
                | Q(user__email__icontains=search)
            )
        tickets = list(rows.order_by('-updated_at')[:300])
        open_count = SupportTicket.objects.exclude(status=SupportTicket.Status.RESOLVED).count()
        return Response(
            {
                'summary': {
                    'total': SupportTicket.objects.count(),
                    'open': SupportTicket.objects.filter(status=SupportTicket.Status.OPEN).count(),
                    'inProgress': SupportTicket.objects.filter(
                        status=SupportTicket.Status.IN_PROGRESS
                    ).count(),
                    'resolved': SupportTicket.objects.filter(status=SupportTicket.Status.RESOLVED).count(),
                    'openTickets': open_count,
                },
                'results': [serialize_ticket(row) for row in tickets],
            }
        )


class AdminSupportTicketDetailView(AdminPanelAPIView):
    def get(self, request, ticket_id):
        try:
            ticket = SupportTicket.objects.select_related('user', 'resolved_by').prefetch_related(
                'messages__author'
            ).get(pk=ticket_id)
        except SupportTicket.DoesNotExist:
            return Response({'detail': 'Support ticket not found.'}, status=404)
        return Response(serialize_ticket(ticket, include_messages=True))

    def post(self, request, ticket_id, action):
        try:
            ticket = SupportTicket.objects.select_related('user').get(pk=ticket_id)
        except SupportTicket.DoesNotExist:
            return Response({'detail': 'Support ticket not found.'}, status=404)

        if action == 'reply':
            body = str(request.data.get('message') or request.data.get('body') or '').strip()
            if not body:
                return Response({'detail': 'Message is required.'}, status=400)
            try:
                admin_reply_to_ticket(ticket, request.user, body)
            except ValueError as exc:
                return Response({'detail': str(exc)}, status=400)
            _audit(
                request,
                action='support_reply',
                target_type='SupportTicket',
                target_id=ticket.id,
                summary=f'Replied to support ticket: {ticket.subject[:120]}',
            )
        elif action == 'resolve':
            note = str(
                request.data.get('resolutionNote')
                or request.data.get('message')
                or request.data.get('body')
                or ''
            ).strip()
            if not note:
                return Response({'detail': 'Resolution note is required.'}, status=400)
            notify_user = request.data.get('notifyUser', True)
            if isinstance(notify_user, str):
                notify_user = notify_user.lower() not in ('0', 'false', 'no')
            try:
                admin_resolve_ticket(
                    ticket,
                    request.user,
                    resolution_note=note,
                    notify_user=bool(notify_user),
                )
            except ValueError as exc:
                return Response({'detail': str(exc)}, status=400)
            _audit(
                request,
                action='support_resolve',
                target_type='SupportTicket',
                target_id=ticket.id,
                summary=f'Resolved support ticket: {ticket.subject[:120]}',
            )
        elif action == 'reopen':
            note = str(request.data.get('message') or request.data.get('note') or '').strip()
            admin_reopen_ticket(ticket, request.user, note)
            _audit(
                request,
                action='support_reopen',
                target_type='SupportTicket',
                target_id=ticket.id,
                summary=f'Reopened support ticket: {ticket.subject[:120]}',
            )
        elif action == 'in-progress':
            ticket.status = SupportTicket.Status.IN_PROGRESS
            ticket.save(update_fields=['status', 'updated_at'])
            _audit(
                request,
                action='support_in_progress',
                target_type='SupportTicket',
                target_id=ticket.id,
                summary=f'Marked support ticket in progress: {ticket.subject[:120]}',
            )
        else:
            return Response({'detail': 'Unsupported action.'}, status=400)

        ticket = SupportTicket.objects.select_related('user', 'resolved_by').prefetch_related(
            'messages__author'
        ).get(pk=ticket_id)
        sync_admin_notifications()
        return Response(serialize_ticket(ticket, include_messages=True))


class AdminBroadcastListView(AdminPanelAPIView):
    def get(self, request):
        rows = AdminBroadcast.objects.select_related('created_by').all()[:100]
        return Response(
            {
                'summary': {'total': AdminBroadcast.objects.count()},
                'results': [serialize_broadcast(row) for row in rows],
            }
        )

    def post(self, request):
        title = str(request.data.get('title') or '').strip()
        message = str(request.data.get('message') or '').strip()
        category = str(request.data.get('category') or 'announcement').strip().lower()
        audience = str(request.data.get('audience') or 'customers').strip().lower()
        try:
            broadcast = send_broadcast(
                admin_user=request.user,
                title=title,
                message=message,
                category=category,
                audience=audience,
            )
        except ValueError as exc:
            return Response({'detail': str(exc)}, status=400)
        _audit(
            request,
            action='broadcast_send',
            target_type='AdminBroadcast',
            target_id=broadcast.id,
            summary=f'Sent {category} to {broadcast.recipient_count} users: {title[:120]}',
            metadata={'category': category, 'audience': audience, 'recipientCount': broadcast.recipient_count},
        )
        return Response(serialize_broadcast(broadcast), status=201)
