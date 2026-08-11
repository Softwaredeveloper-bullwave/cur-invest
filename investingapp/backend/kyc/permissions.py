"""DRF permissions for KYC-gated resources."""

from rest_framework.permissions import BasePermission, IsAuthenticated

from accounts.models import User

from .manual_service import user_kyc_is_verified
from .fno_service import user_fno_is_verified
from .models import KycProfile
from .service import get_or_create_profile

WEB_CLIENT_HEADER = 'X-BullWave-Client'


def is_web_client(request) -> bool:
    return (request.headers.get(WEB_CLIENT_HEADER) or '').strip().lower() == 'web'


def user_is_practice_ready(user: User) -> bool:
    return bool(
        user
        and user.is_authenticated
        and user.email_verified
        and user.has_completed_onboarding
    )


class IsKycVerified(BasePermission):
    message = 'Complete KYC verification to access markets.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if user_kyc_is_verified(request.user):
            return True
        # Legacy Cashfree profile check
        profile = get_or_create_profile(request.user)
        return profile.overall_status == KycProfile.OverallStatus.VERIFIED


class IsFnoVerified(BasePermission):
    message = 'Complete F&O eligibility verification to access derivatives.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return user_fno_is_verified(request.user)


class IsPracticeReady(BasePermission):
    message = 'Verify your email and complete your profile to start paper trading.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        return user_is_practice_ready(request.user)


class IsPaperTradingAllowed(BasePermission):
    """Mobile app: full KYC. Web client: phone + email + profile only."""

    message = 'Complete KYC verification to access markets.'

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False
        if is_web_client(request):
            if user_is_practice_ready(request.user):
                return True
            self.message = IsPracticeReady.message
            return False
        if user_kyc_is_verified(request.user):
            return True
        profile = get_or_create_profile(request.user)
        return profile.overall_status == KycProfile.OverallStatus.VERIFIED


# Browse quotes, news, commodities — login only.
MARKET_BROWSE_PERMISSIONS = [IsAuthenticated]

# Trading, funding, alerts — full KYC on mobile; web paper trading uses IsPaperTradingAllowed.
MARKET_TRADE_PERMISSIONS = [IsAuthenticated, IsKycVerified]

PAPER_TRADE_PERMISSIONS = [IsAuthenticated, IsPaperTradingAllowed]


def trade_permissions_for_request(request):
    """Return permission instances for trade endpoints (web vs mobile)."""
    if is_web_client(request):
        return [IsAuthenticated(), IsPaperTradingAllowed()]
    return [IsAuthenticated(), IsKycVerified()]
