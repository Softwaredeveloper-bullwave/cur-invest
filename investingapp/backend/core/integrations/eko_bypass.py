"""Sandbox/dev Eko fallbacks — never active once EKO_ENVIRONMENT=production.

sandbox_bypass_allowed() hard-refuses to bypass whenever the configured Eko
environment is production, regardless of DEBUG/KYC_AUTO_APPROVE. That's the
guarantee that a "Verified" result only ever comes from a real Eko API call
once real production keys are in place.
"""

from __future__ import annotations

import logging

from django.conf import settings

from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import (
    EkoKycError,
    generate_aadhaar_otp,
    generate_sender_otp,
    get_sender_info,
    onboard_sender,
    verify_aadhaar_otp,
    verify_bank_account,
    verify_pan,
    verify_sender_otp,
    verify_upi_vpa,
)

logger = logging.getLogger('bullwave.kyc')


def sandbox_bypass_allowed() -> bool:
    """Dev/sandbox only — never bypass in production."""
    cfg = eko_settings()
    if cfg.is_production:
        return False
    # A failed Eko request must never silently become "verified". Developers
    # can opt in explicitly when working without UAT service access.
    return bool(getattr(settings, 'EKO_ALLOW_SANDBOX_BYPASS', False))


def should_bypass_eko(exc: EkoKycError) -> bool:
    if not sandbox_bypass_allowed():
        return False
    # Invalid API keys must be fixed — do not mask auth failures.
    if exc.code == 'auth_failed':
        return False
    return True


def mock_pan_result(pan: str, holder_name: str) -> dict:
    name = (holder_name or 'Verified User').strip()
    return {
        'reference_id': f'eko-sandbox-{pan[-4:]}',
        'registered_name': name,
        'pan_type': 'E',
        'name_match_result': 'DIRECT_MATCH',
        'name_match_score': 100,
        'valid': True,
        'dev_bypass': True,
    }


def mock_bank_result(*, account_holder_name: str, ifsc: str) -> dict:
    bank_name = 'Sandbox Bank'
    prefix = ifsc.upper()[:4]
    if prefix == 'HDFC':
        bank_name = 'HDFC Bank'
    elif prefix == 'SBIN':
        bank_name = 'State Bank of India'
    elif prefix == 'ICIC':
        bank_name = 'ICICI Bank'
    return {
        'reference_id': f'eko-sandbox-{ifsc[-4:]}',
        'name_at_bank': account_holder_name,
        'bank_name': bank_name,
        'branch': 'Sandbox Branch',
        'city': 'Mumbai',
        'name_match_result': 'DIRECT_MATCH',
        'name_match_score': 100,
        'account_status': 'VALID',
        'verification_method': 'penny_drop',
        'dev_bypass': True,
    }


def mock_aadhaar_otp_result(aadhaar_number: str) -> dict:
    return {
        'otp_ref_id': f'eko-sandbox-{aadhaar_number[-4:]}',
        'reference_id': f'eko-sandbox-{aadhaar_number[-4:]}',
        'dev_bypass': True,
    }


def mock_aadhaar_verify_result(name: str) -> dict:
    return {
        'reference_id': 'eko-sandbox-aadhaar',
        'name': name or 'Verified User',
        'dev_bypass': True,
    }


def mock_sender_onboard_result() -> dict:
    return {'otp_ref_id': 'eko-sandbox-sender-otp', 'dev_bypass': True}


def mock_sender_otp_verify_result() -> dict:
    return {'dev_bypass': True}


def mock_upi_vpa_result(*, customer_vpa: str, name: str) -> dict:
    return {
        'vpa': customer_vpa.strip().lower(),
        'valid': True,
        'recipient_name': name or 'Verified User',
        'mobile_number': '',
        'reference_id': 'eko-sandbox-upi',
        'dev_bypass': True,
    }


def verify_pan_with_bypass(pan: str, holder_name: str = '') -> dict:
    try:
        return verify_pan(pan, holder_name)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning(
                'Eko PAN blocked (%s) — sandbox dev bypass for %s',
                exc.code or 'error',
                pan[-4:].rjust(len(pan), '*') if pan else '****',
            )
            return mock_pan_result(pan, holder_name)
        raise


def verify_bank_with_bypass(
    *,
    bank_account: str,
    ifsc: str,
    name: str = '',
    phone: str = '',
    dob: str = '',
    address: dict | None = None,
) -> dict:
    try:
        return verify_bank_account(
            bank_account=bank_account, ifsc=ifsc, name=name, phone=phone, dob=dob, address=address
        )
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning(
                'Eko bank verify blocked (%s) — sandbox dev bypass for IFSC %s',
                exc.code or 'error',
                ifsc,
            )
            return mock_bank_result(account_holder_name=name, ifsc=ifsc)
        raise


def get_sender_info_with_bypass(mobile: str) -> dict:
    # No sandbox mock here — this is a read-only lookup, always call Eko for
    # real (or, in sandbox, expect the "not enrolled" branch to drive
    # onboard_sender_with_bypass below).
    try:
        return get_sender_info(mobile)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko sender info lookup blocked (%s) — treating as not-enrolled in sandbox', exc.code or 'error')
            return {'enrolled': False, 'otp_ref_id': ''}
        raise


def onboard_sender_with_bypass(*, mobile: str, name: str, dob: str, address: dict | None = None) -> dict:
    try:
        return onboard_sender(mobile=mobile, name=name, dob=dob, address=address)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko sender onboarding blocked (%s) — sandbox dev bypass', exc.code or 'error')
            return mock_sender_onboard_result()
        raise


def generate_sender_otp_with_bypass(mobile: str) -> dict:
    try:
        return generate_sender_otp(mobile)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko sender OTP resend blocked (%s) — sandbox dev bypass', exc.code or 'error')
            return mock_sender_onboard_result()
        raise


def verify_sender_otp_with_bypass(*, mobile: str, otp: str, otp_ref_id: str) -> dict:
    try:
        return verify_sender_otp(mobile=mobile, otp=otp, otp_ref_id=otp_ref_id)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko sender OTP verify blocked (%s) — sandbox dev bypass', exc.code or 'error')
            return mock_sender_otp_verify_result()
        raise


def generate_aadhaar_otp_with_bypass(*, aadhaar_number: str, name: str, mobile: str) -> dict:
    try:
        return generate_aadhaar_otp(aadhaar_number=aadhaar_number, name=name, mobile=mobile)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko Aadhaar OTP generate blocked (%s) — sandbox dev bypass', exc.code or 'error')
            return mock_aadhaar_otp_result(aadhaar_number)
        raise


def verify_aadhaar_otp_with_bypass(*, mobile: str, otp: str, otp_ref_id: str, name: str = '') -> dict:
    try:
        return verify_aadhaar_otp(mobile=mobile, otp=otp, otp_ref_id=otp_ref_id)
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning('Eko Aadhaar OTP verify blocked (%s) — sandbox dev bypass', exc.code or 'error')
            return mock_aadhaar_verify_result(name)
        raise


def verify_upi_vpa_with_bypass(
    *,
    customer_vpa: str,
    recipient_mobile: str,
    name: str,
    latlong: str = '28.6139,77.2090',
    customer_id: str = '',
    dob: str = '',
    address: dict | None = None,
) -> dict:
    try:
        return verify_upi_vpa(
            customer_vpa=customer_vpa,
            recipient_mobile=recipient_mobile,
            name=name,
            latlong=latlong,
            customer_id=customer_id,
            dob=dob,
            address=address,
        )
    except EkoKycError as exc:
        if should_bypass_eko(exc):
            logger.warning(
                'Eko UPI verify blocked (%s) — sandbox dev bypass for VPA %s',
                exc.code or 'error',
                customer_vpa.split('@', 1)[0][:4] + '@***',
            )
            return mock_upi_vpa_result(customer_vpa=customer_vpa, name=name)
        raise
