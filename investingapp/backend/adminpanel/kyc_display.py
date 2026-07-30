"""Map KycProfile truth into admin-panel user status fields."""

from typing import Optional

from accounts.models import User
from kyc.models import KycProfile


def admin_pan_status(user: User, profile: Optional[KycProfile]) -> str:
    if profile is not None and profile.pan_status:
        return profile.pan_status
    return user.pan_status


def admin_kyc_status(user: User, profile: Optional[KycProfile]) -> str:
    if profile is None:
        return user.kyc_status
    overall = profile.overall_status
    if overall == KycProfile.OverallStatus.VERIFIED:
        return User.KycStatus.COMPLETED
    if overall == KycProfile.OverallStatus.UNDER_REVIEW:
        return 'under_review'
    if overall == KycProfile.OverallStatus.REJECTED:
        return User.KycStatus.REJECTED
    if overall == KycProfile.OverallStatus.PENDING:
        verified = KycProfile.VerificationStatus.VERIFIED
        if (
            profile.pan_status == verified
            or profile.bank_status == verified
            or profile.aadhaar_status == verified
        ):
            return User.KycStatus.IN_PROGRESS
        return User.KycStatus.PENDING
    return user.kyc_status
