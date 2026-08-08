"""KYC business logic — orchestrates verification via per-step providers.

Set KYC_PAN_PROVIDER, KYC_BANK_PROVIDER, KYC_UPI_PROVIDER, and
KYC_AADHAAR_PROVIDER in .env (each: cashfree | eko). When a step-specific
variable is blank, KYC_PROVIDER is used for backward compatibility.
"""

import logging
import hashlib
import re
import secrets
import uuid
from datetime import date, datetime
from difflib import SequenceMatcher
from typing import Optional
from urllib.parse import urlparse

from django.conf import settings
from django.utils import timezone

from accounts.models import BankAccount, User
from accounts.otp_utils import normalize_phone
from services.providers.cashfree_config import cashfree_settings
from services.providers.cashfree_secure_id import (
    CashfreeSecureIdError,
    verify_bank_account as cashfree_verify_bank_account,
    verify_pan as cashfree_verify_pan_direct,
    verify_upi_vpa as cashfree_verify_upi_vpa,
)
from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import (
    EkoKycError,
    create_digilocker_url,
    eko_kyc_billing_status,
    get_digilocker_status,
    mobile_from_upi_vpa,
    verify_bank_account as eko_verify_bank_account,
    verify_pan as eko_verify_pan,
    verify_upi_vpa as eko_verify_upi_vpa,
)
from core.integrations.cashfree_bypass import verify_pan_with_bypass as cashfree_verify_pan_legacy
from core.integrations.eko_bypass import (
    generate_aadhaar_otp_with_bypass,
    generate_sender_otp_with_bypass,
    get_sender_info_with_bypass,
    onboard_sender_with_bypass,
    verify_aadhaar_otp_with_bypass,
    verify_sender_otp_with_bypass,
)

from .providers import (
    aadhaar_provider,
    bank_provider,
    kyc_mode,
    legacy_kyc_provider,
    pan_provider,
    step_providers_payload,
    upi_provider,
    upi_step_required,
)
from .aadhaar_security import decrypt_aadhaar, encrypt_aadhaar
from .masking import mask_account_number, mask_aadhaar, mask_pan, mask_upi_vpa
from .models import BankVerificationRequest, KycProfile, VerificationAuditLog

logger = logging.getLogger('bullwave.kyc')

PAN_REGEX = re.compile(r'^[A-Z]{5}[0-9]{4}[A-Z]$')
IFSC_REGEX = re.compile(r'^[A-Z]{4}0[A-Z0-9]{6}$')
ACCOUNT_REGEX = re.compile(r'^\d{9,18}$')
AADHAAR_REGEX = re.compile(r'^\d{12}$')
UPI_VPA_REGEX = re.compile(r'^[a-z0-9][a-z0-9._-]{1,255}@[a-z0-9._-]{2,64}$', re.IGNORECASE)
DEFAULT_UPI_LATLONG = '28.6139,77.2090'

NAME_MATCH_PASS = frozenset({'DIRECT_MATCH', 'GOOD_PARTIAL_MATCH', 'MODERATE_PARTIAL_MATCH'})
NAME_MATCH_MIN_SCORE = 0.72

# Provider-agnostic error base — service code catches this instead of a
# vendor-specific exception class.
ProviderError = (CashfreeSecureIdError, EkoKycError)


def _kyc_provider() -> str:
    return legacy_kyc_provider()


def _provider_for_step(step: str) -> str:
    mapping = {
        'pan': pan_provider,
        'bank': bank_provider,
        'upi': upi_provider,
        'aadhaar': aadhaar_provider,
    }
    return mapping[step]()


def _provider_configured_for(step: str) -> bool:
    provider = _provider_for_step(step)
    if provider == 'eko':
        return eko_settings().is_configured
    if provider == 'cashfree':
        return cashfree_settings().is_configured
    return False


def _provider_configured() -> bool:
    return any(_provider_configured_for(step) for step in ('pan', 'bank', 'upi', 'aadhaar'))


def _provider_not_configured_error(step: str = 'pan'):
    provider = _provider_for_step(step)
    if provider == 'eko':
        return EkoKycError('Eko KYC API is not configured. Paste EKO_* keys in .env.')
    return CashfreeSecureIdError('Cashfree Secure ID is not configured. Paste CASHFREE_* keys in .env.')


def _verify_pan(pan: str, holder_name: str) -> dict:
    if pan_provider() == 'eko':
        return eko_verify_pan(pan, holder_name)
    if getattr(settings, 'CASHFREE_DEV_BYPASS', False):
        return cashfree_verify_pan_legacy(pan, holder_name)
    return cashfree_verify_pan_direct(pan, holder_name)


def _verify_bank(*, bank_account: str, ifsc: str, name: str, phone: str, dob: str = '', address: dict = None) -> dict:
    if bank_provider() == 'eko':
        return eko_verify_bank_account(
            bank_account=bank_account, ifsc=ifsc, name=name, phone=phone, dob=dob, address=address or {}
        )
    return cashfree_verify_bank_account(bank_account=bank_account, ifsc=ifsc, name=name, phone=phone)


def _verify_upi(
    *,
    customer_vpa: str,
    name: str,
    recipient_mobile: str = '',
    latlong: str = '',
    customer_id: str = '',
    dob: str = '',
    address: Optional[dict] = None,
) -> dict:
    if upi_provider() == 'eko':
        return eko_verify_upi_vpa(
            customer_vpa=customer_vpa,
            recipient_mobile=recipient_mobile,
            name=name,
            latlong=latlong,
            customer_id=customer_id,
            dob=dob,
            address=address,
        )
    return cashfree_verify_upi_vpa(customer_vpa=customer_vpa, name=name)


def _is_fake_verification_reference(reference_id: str) -> bool:
    ref = (reference_id or '').strip().lower()
    return ref == 'soft_verify' or ref.startswith('sandbox-') or ref.startswith('eko-sandbox-')


def _assert_live_provider_verification_only(step: str) -> None:
    """Refuse dev bypass flags — every step must hit a billable API call."""
    provider = _provider_for_step(step)
    if provider == 'eko' and step == 'bank' and getattr(settings, 'EKO_BANK_SOFT_VERIFY', False):
        raise EkoKycError(
            'EKO_BANK_SOFT_VERIFY must stay False so bank verification bills through Eko.',
            'soft_verify_disabled',
        )
    if provider == 'eko' and step == 'upi' and getattr(settings, 'EKO_UPI_SOFT_VERIFY', False):
        raise EkoKycError(
            'EKO_UPI_SOFT_VERIFY must stay False so UPI verification bills through Eko.',
            'soft_verify_disabled',
        )
    if provider == 'cashfree' and step in ('pan', 'bank', 'upi') and getattr(settings, 'CASHFREE_DEV_BYPASS', False):
        raise CashfreeSecureIdError(
            'CASHFREE_DEV_BYPASS must stay False so verification uses live Cashfree APIs.',
            'dev_bypass_disabled',
        )


def get_or_create_profile(user) -> KycProfile:
    profile, _ = KycProfile.objects.get_or_create(user=user)
    if user.phone and not profile.mobile_verified:
        profile.mobile_verified = True
        profile.save(update_fields=['mobile_verified'])
    return profile


def _audit(user, step, status, request_meta=None, response_meta=None, message=''):
    VerificationAuditLog.objects.create(
        user=user,
        step=step,
        status=status,
        message=message[:500],
        request_meta=request_meta or {},
        response_meta=response_meta or {},
    )


def _normalize_name(value: str) -> str:
    return re.sub(r'[^A-Z0-9 ]', '', (value or '').upper()).strip()


def _name_similarity(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    return SequenceMatcher(None, _normalize_name(a), _normalize_name(b)).ratio()


def _name_match_label(score: float) -> str:
    if score >= 0.92:
        return 'DIRECT_MATCH'
    if score >= NAME_MATCH_MIN_SCORE:
        return 'GOOD_PARTIAL_MATCH'
    return 'NO_MATCH'


def _identity_names_for_bank(profile: KycProfile, user) -> list[str]:
    """Verified identity names the linked bank account must match."""
    names: list[str] = []
    verified = KycProfile.VerificationStatus.VERIFIED
    if profile.pan_status == verified and profile.pan_name.strip():
        names.append(profile.pan_name.strip())
    if profile.aadhaar_status == verified and profile.aadhaar_name.strip():
        names.append(profile.aadhaar_name.strip())
    if user.name.strip():
        names.append(user.name.strip())
    return names


def _score_bank_name_against_identity(profile: KycProfile, user, name_at_bank: str) -> tuple[float, str]:
    name_at_bank = (name_at_bank or '').strip()
    if not name_at_bank:
        return 0.0, 'NO_MATCH'
    identity_names = _identity_names_for_bank(profile, user)
    if not identity_names:
        return 0.0, 'NO_MATCH'
    best_score = max(_name_similarity(identity, name_at_bank) for identity in identity_names)
    return best_score, _name_match_label(best_score)


def _bank_skip_identity_match() -> bool:
    return bool(getattr(settings, 'KYC_BANK_SKIP_IDENTITY_MATCH', False))


def _resolve_bank_holder_name(
    profile: KycProfile,
    user,
    *,
    submitted_name: str,
) -> str:
    """PAN-verified name is the legal anchor — submitted name cannot override it."""
    submitted = (submitted_name or '').strip()
    verified = KycProfile.VerificationStatus.VERIFIED
    if profile.pan_status == verified and profile.pan_name.strip():
        pan_name = profile.pan_name.strip()
        if submitted and _name_similarity(submitted, pan_name) < NAME_MATCH_MIN_SCORE:
            raise ValueError('Account holder name must match your verified PAN name.')
        return pan_name
    if submitted:
        return submitted
    if user.name.strip():
        return user.name.strip()
    raise ValueError('Enter the account holder name exactly as it appears on your bank account.')


def _assert_bank_identity_match(profile: KycProfile, user, *, result: dict) -> tuple[float, str]:
    """Reject third-party bank accounts — name at bank must match verified identity."""
    name_at_bank = (result.get('name_at_bank') or '').strip()
    if not name_at_bank:
        raise ValueError('Bank verified but account holder name was missing from the provider response.')

    provider_match = (result.get('name_match_result') or '').upper()
    if provider_match and provider_match not in NAME_MATCH_PASS:
        raise ValueError(
            'The name on this bank account does not match the account holder name on record.'
        )

    score, label = _score_bank_name_against_identity(profile, user, name_at_bank)
    if score < NAME_MATCH_MIN_SCORE:
        raise ValueError(
            'This bank account is not in your name. It must match your verified PAN or Aadhaar identity.'
        )
    return score, label


def _format_verified_name(name: str) -> str:
    """Human-friendly display name from provider-verified identity."""
    return ' '.join((name or '').split()).title()


def _parse_dob_string(value: str) -> Optional[date]:
    cleaned = (value or '').strip()
    if not cleaned:
        return None
    for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%d/%m/%y', '%d-%m-%y'):
        try:
            sample = cleaned[:10] if fmt == '%Y-%m-%d' else cleaned[:10]
            return datetime.strptime(sample, fmt).date()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(cleaned.replace('Z', '+00:00')[:19]).date()
    except ValueError:
        return None


def _parse_provider_dob(payload) -> Optional[date]:
    if payload is None:
        return None
    if isinstance(payload, date) and not isinstance(payload, datetime):
        return payload
    if isinstance(payload, datetime):
        return payload.date()
    if isinstance(payload, str):
        return _parse_dob_string(payload)
    if isinstance(payload, dict):
        for key in ('dob', 'date_of_birth', 'dateOfBirth', 'birth_date', 'birthDate', 'd_o_b'):
            parsed = _parse_dob_string(str(payload.get(key) or ''))
            if parsed:
                return parsed
    return None


def _best_verified_dob(profile: KycProfile) -> Optional[date]:
    verified = KycProfile.VerificationStatus.VERIFIED
    if profile.pan_status == verified and profile.pan_dob:
        return profile.pan_dob
    if profile.aadhaar_status == verified and profile.aadhaar_dob:
        return profile.aadhaar_dob
    return None


def _sync_user_dob_from_kyc(user, profile: KycProfile) -> None:
    """Keep accounts.User.date_of_birth aligned with verified PAN / Aadhaar identity."""
    verified_dob = _best_verified_dob(profile)
    if not verified_dob:
        return
    if user.date_of_birth != verified_dob:
        user.date_of_birth = verified_dob
        user.save(update_fields=['date_of_birth'])


def _best_verified_name(profile: KycProfile) -> str:
    """Prefer PAN name once verified — it is the legal identity anchor."""
    verified = KycProfile.VerificationStatus.VERIFIED
    if profile.pan_status == verified and profile.pan_name.strip():
        return _format_verified_name(profile.pan_name)
    if profile.bank_status == verified and profile.name_at_bank.strip():
        return _format_verified_name(profile.name_at_bank)
    if profile.aadhaar_status == verified and profile.aadhaar_name.strip():
        return _format_verified_name(profile.aadhaar_name)
    return ''


def _sync_user_name_from_kyc(user, profile: KycProfile) -> None:
    """Keep accounts.User.name aligned with verified KYC identity."""
    verified_name = _best_verified_name(profile)
    if not verified_name:
        return

    user_updates: list[str] = []
    if user.name != verified_name:
        user.name = verified_name
        user_updates.append('name')
    if user_updates:
        user.save(update_fields=user_updates)

    verified = KycProfile.VerificationStatus.VERIFIED
    holder_name = ''
    if profile.bank_status == verified and profile.name_at_bank.strip():
        holder_name = _format_verified_name(profile.name_at_bank)
    elif profile.pan_status == verified and profile.pan_name.strip():
        holder_name = _format_verified_name(profile.pan_name)

    profile_updates: list[str] = []
    if holder_name and profile.account_holder_name != holder_name:
        profile.account_holder_name = holder_name
        profile_updates.append('account_holder_name')
    if profile_updates:
        profile.save(update_fields=profile_updates)


def verify_pan_step(user, pan: str, holder_name: str = '') -> KycProfile:
    pan = pan.upper().strip()
    if not PAN_REGEX.match(pan):
        raise ValueError('Invalid PAN format.')

    profile = get_or_create_profile(user)
    _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.STARTED, {'pan': mask_pan(pan)})

    if not _provider_configured_for('pan'):
        raise _provider_not_configured_error('pan')

    _assert_live_provider_verification_only('pan')

    if _is_fake_verification_reference(profile.pan_reference_id):
        profile.pan_status = KycProfile.VerificationStatus.PENDING
        profile.pan_reference_id = ''
        profile.pan_verified_at = None
        profile.pan_failure_reason = ''
        profile.save(
            update_fields=['pan_status', 'pan_reference_id', 'pan_verified_at', 'pan_failure_reason']
        )

    try:
        result = _verify_pan(pan, holder_name or profile.pan_name or user.name)
    except ProviderError as exc:
        profile.pan_status = KycProfile.VerificationStatus.FAILED
        profile.pan_failure_reason = str(exc)[:280]
        profile.save(update_fields=['pan_status', 'pan_failure_reason'])
        _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    if result.get('dev_bypass'):
        raise CashfreeSecureIdError(
            'Sandbox dev bypass is disabled. Whitelist your server IP in Cashfree Secure ID.',
            'dev_bypass_disabled',
        )

    profile.pan_number = pan
    profile.pan_name = result['registered_name'] or holder_name
    profile.pan_status = KycProfile.VerificationStatus.VERIFIED
    profile.pan_reference_id = result.get('reference_id', '')
    profile.pan_verified_at = timezone.now()
    profile.pan_failure_reason = ''
    pan_dob = _parse_provider_dob(result)
    if pan_dob:
        profile.pan_dob = pan_dob
    profile.save()
    _sync_user_name_from_kyc(user, profile)
    _sync_user_dob_from_kyc(user, profile)
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.PAN, VerificationAuditLog.Status.SUCCESS, response_meta={
        **result,
        'provider': pan_provider(),
        'provider_billed': True,
        'provider_reference_id': result.get('reference_id', ''),
    })
    return profile


def _is_marketing_redirect_url(url: str) -> bool:
    """True when the URL is the public marketing site, not a KYC callback."""
    normalized = (url or '').rstrip('/').lower()
    share = (getattr(settings, 'APP_SHARE_URL', '') or '').rstrip('/').lower()
    blocked = {
        'https://bullwave.in',
        'https://www.bullwave.in',
        share,
    }
    return normalized in blocked


def _is_localhost_public_url(url: str) -> bool:
    """True when BACKEND_PUBLIC_URL points at this machine (http or https)."""
    if not url:
        return False
    host = (urlparse(url).hostname or '').lower()
    return host in {'127.0.0.1', 'localhost', '0.0.0.0', '::1'}


def _digilocker_callback_base(public_url: str, tunnel_url: str) -> str:
    """Pick HTTPS base for DigiLocker callback — production API beats local tunnel."""
    if public_url.startswith('https://') and not _is_localhost_public_url(public_url):
        return public_url
    if tunnel_url.startswith('https://'):
        return tunnel_url
    if public_url.startswith('https://'):
        return public_url
    return ''


def _digilocker_redirect_url() -> tuple[str, str]:
    """Return (redirect_url, state_token) for Eko DigiLocker consent."""
    public_url = (getattr(settings, 'BACKEND_PUBLIC_URL', '') or '').rstrip('/')
    tunnel_url = (getattr(settings, 'LOCAL_DEV_TUNNEL_URL', '') or '').rstrip('/')
    configured = (
        getattr(settings, 'EKO_DIGILOCKER_REDIRECT_URL', '') or ''
    ).rstrip('/')

    state = secrets.token_urlsafe(32)

    callback_base = _digilocker_callback_base(public_url, tunnel_url)
    if callback_base:
        return f'{callback_base}/api/v1/digilocker/callback/{state}/', state

    if configured and not _is_marketing_redirect_url(configured):
        if '{state}' in configured:
            return configured.format(state=state), state
        return configured, ''

    raise EkoKycError(
        'DigiLocker needs a public HTTPS callback URL. For local dev run in another terminal: '
        'npx localtunnel --port 8000 — then set LOCAL_DEV_TUNNEL_URL=https://YOUR-ID.loca.lt in .env '
        '(or set BACKEND_PUBLIC_URL to your deployed API, e.g. https://api.bullwave.in). '
        'Never use https://bullwave.in as redirect.',
        'public_redirect_required',
    )


def start_aadhaar_digilocker_step(user) -> KycProfile:
    """Create the supported Eko DigiLocker consent journey after PAN."""
    if aadhaar_provider() != 'eko':
        raise EkoKycError(
            'DigiLocker verification requires KYC_AADHAAR_PROVIDER=eko.',
            'unsupported_provider',
        )

    profile = get_or_create_profile(user)
    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('Verify PAN before Aadhaar verification.')
    if profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED:
        return profile
    if not eko_settings().is_configured:
        raise EkoKycError('Eko KYC API is not configured. Paste EKO_* keys in .env.')
    redirect_url, state = _digilocker_redirect_url()

    # Eko enforces a hard 20-character maximum and returns an opaque HTML 403
    # instead of a validation error when this value is longer.
    client_ref_id = uuid.uuid4().hex[:20]

    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.STARTED,
        {'method': 'digilocker'},
    )
    try:
        result = create_digilocker_url(
            client_ref_id=client_ref_id,
            redirect_url=redirect_url,
        )
    except EkoKycError as exc:
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
    profile.aadhaar_failure_reason = ''
    profile.aadhaar_reference_id = result['reference_id']
    profile.aadhaar_digilocker_url = result['url']
    profile.aadhaar_digilocker_client_ref_id = client_ref_id
    profile.aadhaar_digilocker_verification_id = result.get('verification_id', '')
    profile.aadhaar_digilocker_state_digest = (
        hashlib.sha256(state.encode()).hexdigest() if state else ''
    )
    profile.aadhaar_digilocker_started_at = timezone.now()
    # Clear obsolete OTP state so clients cannot resume the unsupported flow.
    profile.aadhaar_number = ''
    profile.aadhaar_otp_ref_id = ''
    profile.aadhaar_sender_otp_ref_id = ''
    profile.save()
    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.SUCCESS,
        response_meta={
            'stage': 'digilocker_url_created',
            'reference_id': result['reference_id'],
            'provider': aadhaar_provider(),
            'provider_billed': True,
        },
    )
    return profile


def digilocker_app_return_url(*, verification_id: str = '') -> str:
    """Deep-link back into the Flutter app after the browser callback."""
    base = (getattr(settings, 'APP_WEB_URL', '') or '').rstrip('/')
    if not base:
        return ''
    query = 'digilocker=1'
    if verification_id:
        query = f'{query}&verification_id={verification_id}'
    return f'{base}/#/kyc/aadhaar?{query}'


def record_digilocker_callback(*, state: str, verification_id: str = '') -> bool:
    """Record Eko's browser redirect without requiring the user's JWT."""
    if not state:
        return False
    digest = hashlib.sha256(state.encode()).hexdigest()
    try:
        profile = KycProfile.objects.get(aadhaar_digilocker_state_digest=digest)
    except KycProfile.DoesNotExist:
        return False
    if verification_id:
        profile.aadhaar_digilocker_verification_id = verification_id[:255]
        profile.save(update_fields=['aadhaar_digilocker_verification_id'])
    return True


def check_aadhaar_digilocker_step(user, *, verification_id: str = '') -> KycProfile:
    """Fetch Eko's DigiLocker status and persist verified Aadhaar identity."""
    profile = get_or_create_profile(user)
    if profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED:
        return profile
    if not profile.aadhaar_reference_id or not profile.aadhaar_digilocker_client_ref_id:
        raise ValueError('Start DigiLocker verification first.')

    incoming_verification_id = (verification_id or '').strip()
    if incoming_verification_id:
        profile.aadhaar_digilocker_verification_id = incoming_verification_id[:255]
        profile.save(update_fields=['aadhaar_digilocker_verification_id'])

    active_verification_id = profile.aadhaar_digilocker_verification_id

    try:
        result = get_digilocker_status(
            reference_id=profile.aadhaar_reference_id,
            client_ref_id=profile.aadhaar_digilocker_client_ref_id,
            verification_id=active_verification_id,
        )
    except EkoKycError as exc:
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_failure_reason'])
        if 'session_expired' in str(getattr(exc, 'code', '')).lower() or 'expired' in str(exc).lower():
            raise EkoKycError(
                'DigiLocker session expired. Tap “Start a new verification” and complete consent again.',
                'session_expired',
            ) from exc
        raise

    verification_id = result.get('verification_id', '')
    if verification_id:
        profile.aadhaar_digilocker_verification_id = verification_id[:255]

    status_value = (result.get('verification_status') or '').upper()
    details = result.get('user_details') or {}
    name = (details.get('name') or '').strip()
    eaadhaar = str(details.get('eaadhaar') or '').strip().upper()
    consent_granted = _digilocker_aadhaar_consent(result.get('document_consent'))
    identity_available = bool(name) and (consent_granted or eaadhaar in {'Y', 'YES', 'TRUE', '1'})

    if status_value in {'FAILED', 'EXPIRED', 'CONSENT_DENIED', 'CANCELLED', 'REJECTED'}:
        message = f'DigiLocker verification was not completed ({status_value.lower()}).'
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = message
        profile.save()
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=message)
        return profile

    if not identity_available:
        profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
        profile.aadhaar_failure_reason = ''
        profile.save()
        return profile

    pan_name = profile.pan_name or user.name
    if _name_similarity(pan_name, name) < 0.72:
        message = 'Name in DigiLocker does not match the verified PAN name.'
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = message
        profile.save()
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=message)
        raise EkoKycError(message, 'name_mismatch')

    profile.aadhaar_name = name
    profile.aadhaar_status = KycProfile.VerificationStatus.VERIFIED
    profile.aadhaar_failure_reason = ''
    profile.aadhaar_verified_at = timezone.now()
    profile.aadhaar_digilocker_url = ''
    profile.aadhaar_digilocker_state_digest = ''
    aadhaar_dob = _parse_provider_dob(details)
    if aadhaar_dob:
        profile.aadhaar_dob = aadhaar_dob
    profile.save()
    _sync_user_name_from_kyc(user, profile)
    _sync_user_dob_from_kyc(user, profile)
    _update_overall_status(profile)
    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.SUCCESS,
        response_meta={
            'method': 'digilocker',
            'reference_id': profile.aadhaar_reference_id,
            'provider': aadhaar_provider(),
            'provider_billed': True,
        },
    )
    return profile


def _digilocker_aadhaar_consent(consent) -> bool:
    for item in consent if isinstance(consent, list) else [consent]:
        if isinstance(item, dict):
            document = str(item.get('document_type') or item.get('document') or '').upper()
            granted = str(item.get('consent') or item.get('status') or '').upper()
            if document == 'AADHAAR' and granted in {'Y', 'YES', 'TRUE', '1', 'GRANTED'}:
                return True
        elif 'AADHAAR' in str(item or '').upper():
            return True
    return False


def _do_generate_aadhaar_otp(user, profile: KycProfile, aadhaar_number: str) -> KycProfile:
    """Actually call Eko's Aadhaar-OTP-generate endpoint (sender must already
    be onboarded) and persist the resulting OTP reference."""
    result = generate_aadhaar_otp_with_bypass(
        aadhaar_number=aadhaar_number,
        name=profile.pan_name or user.name,
        mobile=user.phone,
    )
    profile.aadhaar_number = encrypt_aadhaar(aadhaar_number)
    profile.aadhaar_last4 = aadhaar_number[-4:]
    profile.aadhaar_otp_ref_id = result['otp_ref_id']
    profile.aadhaar_reference_id = result.get('reference_id', '')
    profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
    profile.aadhaar_failure_reason = ''
    profile.aadhaar_otp_sent_at = timezone.now()
    profile.save()
    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.SUCCESS, response_meta=result)
    return profile


def send_aadhaar_otp_step(user, aadhaar_number: str) -> KycProfile:
    """Step 1 of Aadhaar eKYC — send OTP to the mobile linked to this Aadhaar.

    Eko-only (Cashfree Secure ID doesn't offer Aadhaar OTP in this app).
    Runs after PAN is verified, same as the existing PAN → bank ordering.

    Eko requires the mobile number to be onboarded as a DigiKhata "sender"
    before Aadhaar OTP generation will succeed (this is what produces Eko's
    real "Customer Not Enrolled" error otherwise). We check enrollment first
    and, if needed, onboard the sender — which itself sends a separate
    mobile-verification OTP that must be confirmed via
    verify_sender_otp_step() before we can proceed to the actual Aadhaar OTP.
    """
    aadhaar_number = re.sub(r'\s', '', aadhaar_number or '')
    if not AADHAAR_REGEX.match(aadhaar_number):
        raise ValueError('Aadhaar number must be 12 digits.')

    if aadhaar_provider() != 'eko':
        raise EkoKycError(
            'Aadhaar verification requires KYC_AADHAAR_PROVIDER=eko.',
            'unsupported_provider',
        )

    profile = get_or_create_profile(user)
    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('Verify PAN before Aadhaar verification.')
    if profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED:
        return profile

    # A new request supersedes any previous Aadhaar OTP reference. This
    # prevents a failed redispatch from reopening an OTP form with stale state.
    profile.aadhaar_number = ''
    profile.aadhaar_last4 = ''
    profile.aadhaar_otp_ref_id = ''
    profile.aadhaar_failure_reason = ''
    profile.save(
        update_fields=[
            'aadhaar_number',
            'aadhaar_last4',
            'aadhaar_otp_ref_id',
            'aadhaar_failure_reason',
        ]
    )

    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.STARTED,
        {'aadhaar': mask_aadhaar(aadhaar_number)},
    )

    if not eko_settings().is_configured:
        raise EkoKycError('Eko KYC API is not configured. Paste EKO_* keys in .env.')

    try:
        if not profile.aadhaar_sender_enrolled:
            sender_info = get_sender_info_with_bypass(user.phone)

            if sender_info.get('enrolled'):
                # Fully enrolled already — skip onboarding entirely and go
                # straight to the real Aadhaar OTP.
                profile.aadhaar_sender_enrolled = True
                profile.save(update_fields=['aadhaar_sender_enrolled'])

            elif sender_info.get('otp_ref_id'):
                # Eko's "Get Sender Info" can hand back a leftover otp_ref_id
                # from an earlier, possibly-expired pending session (real
                # production case: it kept returning intent_id=19's old
                # reference, which no longer matched the SMS actually on the
                # phone — Eko rejected every OTP against it with "Invalid
                # OTP"). Reusing that stale reference is exactly the bug, so
                # instead we explicitly request a *fresh* OTP dispatch via
                # the dedicated resend endpoint, which guarantees the
                # otp_ref_id we save is synchronized with the SMS just sent.
                resend_result = generate_sender_otp_with_bypass(user.phone)
                profile.aadhaar_number = encrypt_aadhaar(aadhaar_number)
                profile.aadhaar_last4 = aadhaar_number[-4:]
                profile.aadhaar_sender_otp_ref_id = resend_result['otp_ref_id']
                profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
                profile.aadhaar_failure_reason = ''
                profile.save()
                _audit(
                    user,
                    VerificationAuditLog.Step.AADHAAR,
                    VerificationAuditLog.Status.SUCCESS,
                    response_meta={'stage': 'sender_otp_freshly_sent'},
                )
                return profile

            else:
                return _start_sender_onboarding(user, profile, aadhaar_number)

        try:
            return _do_generate_aadhaar_otp(user, profile, aadhaar_number)
        except EkoKycError as exc:
            # Our local aadhaar_sender_enrolled flag said this mobile was
            # already onboarded, but Eko's own backend disagrees — confirmed
            # in production where a genuinely new test account still had
            # aadhaar_sender_enrolled=True (stale/incorrect) and the Aadhaar
            # OTP call itself failed with "customer_id does not exist in
            # system". Don't just fail here: self-heal by clearing the stale
            # flag and re-running the sender-onboarding flow, exactly as if
            # this were a brand-new sender.
            if 'does not exist' in str(exc).lower() or 'not enrolled' in str(exc).lower():
                profile.aadhaar_sender_enrolled = False
                profile.save(update_fields=['aadhaar_sender_enrolled'])
                return _start_sender_onboarding(user, profile, aadhaar_number)
            raise
    except EkoKycError as exc:
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise


def _start_sender_onboarding(user, profile: KycProfile, aadhaar_number: str) -> KycProfile:
    """Onboard a genuinely-new (or newly-discovered-as-not-really-enrolled)
    mobile number as a DigiKhata sender, and persist the pending OTP state.
    Shared by the first-time path and the self-heal path in
    send_aadhaar_otp_step().
    """
    if not user.date_of_birth:
        raise EkoKycError(
            'Date of birth is required to enroll for Aadhaar verification. '
            'Please add it to your profile first.',
            'dob_required',
        )
    onboard_result = onboard_sender_with_bypass(
        mobile=user.phone,
        name=profile.pan_name or user.name,
        dob=user.date_of_birth.isoformat(),
        address={'city': user.city or ''},
    )
    profile.aadhaar_number = encrypt_aadhaar(aadhaar_number)
    profile.aadhaar_last4 = aadhaar_number[-4:]
    profile.aadhaar_sender_otp_ref_id = onboard_result['otp_ref_id']
    profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
    profile.aadhaar_failure_reason = ''
    profile.save()
    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.SUCCESS,
        response_meta={'stage': 'sender_onboarding_otp_sent'},
    )
    return profile


def resend_aadhaar_otp_step(user) -> KycProfile:
    """Generate a fresh Aadhaar OTP using the encrypted pending number."""
    profile = get_or_create_profile(user)
    if not profile.aadhaar_sender_enrolled or not profile.aadhaar_number:
        raise ValueError('Start Aadhaar verification first.')

    aadhaar_number = decrypt_aadhaar(profile.aadhaar_number)
    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.STARTED, {'resend': True})
    try:
        return _do_generate_aadhaar_otp(user, profile, aadhaar_number)
    except EkoKycError as exc:
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise


def resend_sender_otp_step(user) -> KycProfile:
    """Request a fresh mobile-verification OTP when the pending one has
    expired (Eko's real "Validate OTP Failed" / similar errors after enough
    time has passed) — calls Eko's dedicated resend endpoint instead of
    reusing the stale reference from get_sender_info().
    """
    profile = get_or_create_profile(user)
    if not profile.aadhaar_sender_otp_ref_id and not profile.aadhaar_number:
        raise ValueError('Start Aadhaar verification first.')

    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.STARTED, {'resend': True})

    try:
        result = generate_sender_otp_with_bypass(user.phone)
    except EkoKycError as exc:
        profile.aadhaar_status = KycProfile.VerificationStatus.FAILED
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    profile.aadhaar_sender_otp_ref_id = result['otp_ref_id']
    profile.aadhaar_failure_reason = ''
    profile.save(update_fields=['aadhaar_sender_otp_ref_id', 'aadhaar_failure_reason'])
    _audit(
        user,
        VerificationAuditLog.Step.AADHAAR,
        VerificationAuditLog.Status.SUCCESS,
        response_meta={'stage': 'sender_otp_resent'},
    )
    return profile


def verify_sender_otp_step(user, otp: str) -> KycProfile:
    """Confirm the mobile-verification OTP from Eko's sender onboarding step,
    then immediately trigger the real Aadhaar OTP now that the sender is enrolled.
    """
    otp = (otp or '').strip()
    if not otp:
        raise ValueError('Enter the verification code sent to your mobile number.')

    profile = get_or_create_profile(user)
    if not profile.aadhaar_sender_otp_ref_id:
        raise ValueError('Start Aadhaar verification first.')

    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.STARTED, {'sender_otp_submitted': True})

    try:
        verify_sender_otp_with_bypass(
            mobile=user.phone,
            otp=otp,
            otp_ref_id=profile.aadhaar_sender_otp_ref_id,
        )
        profile.aadhaar_sender_enrolled = True
        profile.aadhaar_sender_otp_ref_id = ''
        profile.save(update_fields=['aadhaar_sender_enrolled', 'aadhaar_sender_otp_ref_id'])
        _audit(
            user,
            VerificationAuditLog.Step.AADHAAR,
            VerificationAuditLog.Status.SUCCESS,
            response_meta={'stage': 'sender_enrolled'},
        )
        return _do_generate_aadhaar_otp(user, profile, decrypt_aadhaar(profile.aadhaar_number))
    except EkoKycError as exc:
        # A rejected/expired OTP is retryable and must not reject KYC.
        profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise


def verify_aadhaar_otp_step(user, otp: str) -> KycProfile:
    """Step 2 of Aadhaar eKYC — verify the OTP sent to the Aadhaar-linked mobile."""
    otp = (otp or '').strip()
    if not otp:
        raise ValueError('Enter the OTP sent to your Aadhaar-linked mobile number.')

    profile = get_or_create_profile(user)
    if not profile.aadhaar_otp_ref_id:
        raise ValueError('Request an Aadhaar OTP first.')

    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.STARTED, {'otp_submitted': True})

    try:
        result = verify_aadhaar_otp_with_bypass(
            mobile=user.phone,
            otp=otp,
            otp_ref_id=profile.aadhaar_otp_ref_id,
            name=profile.pan_name or user.name,
        )
    except EkoKycError as exc:
        # Invalid Aadhaar OTP attempts are retryable; preserve the ref so the
        # user can correct the code without restarting verification.
        profile.aadhaar_status = KycProfile.VerificationStatus.PENDING
        profile.aadhaar_failure_reason = str(exc)[:280]
        profile.save(update_fields=['aadhaar_status', 'aadhaar_failure_reason'])
        _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    profile.aadhaar_status = KycProfile.VerificationStatus.VERIFIED
    profile.aadhaar_name = result.get('name') or profile.aadhaar_name
    profile.aadhaar_reference_id = result.get('reference_id', profile.aadhaar_reference_id)
    # The provider no longer needs the Aadhaar number after OTP validation.
    profile.aadhaar_number = ''
    profile.aadhaar_otp_ref_id = ''
    profile.aadhaar_sender_otp_ref_id = ''
    profile.aadhaar_failure_reason = ''
    profile.aadhaar_verified_at = timezone.now()
    aadhaar_dob = _parse_provider_dob(result)
    if aadhaar_dob:
        profile.aadhaar_dob = aadhaar_dob
    profile.save()
    _sync_user_name_from_kyc(user, profile)
    _sync_user_dob_from_kyc(user, profile)
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.AADHAAR, VerificationAuditLog.Status.SUCCESS, response_meta=result)
    return profile


def verify_bank_step(
    user,
    *,
    account_holder_name: str,
    account_number: str,
    confirm_account_number: str,
    ifsc: str,
    address_line: str = '',
    address_state: str = '',
    address_pincode: str = '',
    address_district: str = '',
    address_area: str = '',
) -> KycProfile:
    account_holder_name = account_holder_name.strip()
    account_number = re.sub(r'\s', '', account_number)
    confirm_account_number = re.sub(r'\s', '', confirm_account_number)
    ifsc = ifsc.upper().strip()

    if account_number != confirm_account_number:
        raise ValueError('Account numbers do not match.')
    if not ACCOUNT_REGEX.match(account_number):
        raise ValueError('Account number must be 9–18 digits.')
    if not IFSC_REGEX.match(ifsc):
        raise ValueError('Invalid IFSC format.')

    profile = get_or_create_profile(user)
    if _bank_skip_identity_match():
        holder_name = (
            account_holder_name.strip()
            or profile.pan_name.strip()
            or user.name.strip()
        )
        if not holder_name:
            raise ValueError('Enter the account holder name as registered with the bank.')
    else:
        holder_name = _resolve_bank_holder_name(
            profile,
            user,
            submitted_name=account_holder_name,
        )
    account_holder_name = holder_name

    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        if settings.DEBUG:
            logger.warning(
                'DEBUG: bypassing PAN prerequisite for bank verification (user=%s)',
                user.phone,
            )
        else:
            raise ValueError('Verify PAN before bank verification.')

    logger.info(
        'Bank verify step started user=%s account=%s ifsc=%s provider=%s pan_bypass=%s',
        user.phone,
        mask_account_number(account_number),
        ifsc,
        bank_provider(),
        settings.DEBUG and profile.pan_status != KycProfile.VerificationStatus.VERIFIED,
    )

    if getattr(settings, 'KYC_BANK_REVIEW_MODE', 'provider') == 'manual':
        from .bank_manual_service import ManualBankReviewError, save_bank_draft

        try:
            save_bank_draft(
                user,
                account_holder_name=account_holder_name or user.name,
                account_number=account_number,
                ifsc=ifsc,
            )
        except ManualBankReviewError as exc:
            raise ValueError(str(exc)) from exc
        logger.info(
            'Bank draft saved for manual payment review user=%s account=%s ifsc=%s',
            user.phone,
            mask_account_number(account_number),
            ifsc,
        )
        return get_or_create_profile(user)

    if (
        _bank_really_verified(profile)
        and profile.bank_account_number == account_number
        and profile.bank_ifsc == ifsc
    ):
        return profile

    if _is_fake_verification_reference(profile.bank_reference_id):
        profile.bank_status = KycProfile.VerificationStatus.PENDING
        profile.bank_reference_id = ''
        profile.bank_verification_method = ''
        profile.bank_verified_at = None
        profile.bank_failure_reason = ''
        profile.bank_name = ''
        profile.bank_branch = ''
        profile.name_at_bank = ''
        profile.bank_utr = ''
        profile.bank_account_status = ''
        profile.bank_account_status_code = ''
        profile.save(
            update_fields=[
                'bank_status',
                'bank_reference_id',
                'bank_verification_method',
                'bank_verified_at',
                'bank_failure_reason',
                'bank_name',
                'bank_branch',
                'name_at_bank',
                'bank_utr',
                'bank_account_status',
                'bank_account_status_code',
            ]
        )

    bank_changed = (
        profile.bank_status == KycProfile.VerificationStatus.VERIFIED
        and (
            (profile.bank_account_number and profile.bank_account_number != account_number)
            or (profile.bank_ifsc and profile.bank_ifsc != ifsc)
        )
    )
    if bank_changed:
        profile.name_match_passed = False
        profile.name_match_result = ''
        profile.name_match_score = 0
        profile.name_match_checked_at = None
        profile.save(
            update_fields=[
                'name_match_passed',
                'name_match_result',
                'name_match_score',
                'name_match_checked_at',
            ]
        )

    _audit(
        user,
        VerificationAuditLog.Step.BANK,
        VerificationAuditLog.Status.STARTED,
        {'account': mask_account_number(account_number), 'ifsc': ifsc},
    )

    if not _provider_configured_for('bank'):
        raise _provider_not_configured_error('bank')

    _assert_live_provider_verification_only('bank')

    try:
        result = _verify_bank(
            bank_account=account_number,
            ifsc=ifsc,
            name=account_holder_name,
            phone=user.phone,
            dob=user.date_of_birth.isoformat() if user.date_of_birth else '',
            address={
                'line': address_line,
                'city': user.city or '',
                'state': address_state,
                'pincode': address_pincode,
                'district': address_district,
                'area': address_area,
            },
        )
    except ProviderError as exc:
        profile.bank_status = KycProfile.VerificationStatus.FAILED
        profile.bank_failure_reason = str(exc)[:280]
        profile.save(update_fields=['bank_status', 'bank_failure_reason'])
        response_meta = {'provider': bank_provider(), 'code': getattr(exc, 'code', '') or ''}
        eko_meta = getattr(exc, 'eko_meta', None)
        if eko_meta:
            response_meta['eko'] = eko_meta
        _audit(
            user,
            VerificationAuditLog.Step.BANK,
            VerificationAuditLog.Status.FAILED,
            message=str(exc),
            response_meta=response_meta,
        )
        raise

    if result.get('dev_bypass'):
        profile.bank_status = KycProfile.VerificationStatus.FAILED
        profile.bank_failure_reason = (
            'Bank verification requires live Cashfree/Eko API access. Whitelist your server IP.'
        )[:280]
        profile.save(update_fields=['bank_status', 'bank_failure_reason'])
        raise CashfreeSecureIdError(profile.bank_failure_reason, 'dev_bypass_disabled')

    if _bank_skip_identity_match():
        match_score, match_label = _score_bank_name_against_identity(
            profile, user, result.get('name_at_bank', '')
        )
        logger.warning(
            'KYC_BANK_SKIP_IDENTITY_MATCH=True — bank verified without enforcing PAN/name match '
            '(user=%s, name_at_bank=%s, score=%.2f)',
            user.phone,
            (result.get('name_at_bank') or '')[:40],
            match_score,
        )
    else:
        try:
            match_score, match_label = _assert_bank_identity_match(profile, user, result=result)
        except ValueError as exc:
            profile.bank_status = KycProfile.VerificationStatus.FAILED
            profile.bank_failure_reason = str(exc)[:280]
            profile.name_at_bank = (result.get('name_at_bank') or '')[:120]
            profile.name_match_result = 'NO_MATCH'
            profile.name_match_score = round(
                _score_bank_name_against_identity(profile, user, result.get('name_at_bank', ''))[0] * 100,
                2,
            )
            profile.name_match_passed = False
            profile.name_match_checked_at = timezone.now()
            profile.save(
                update_fields=[
                    'bank_status',
                    'bank_failure_reason',
                    'name_at_bank',
                    'name_match_result',
                    'name_match_score',
                    'name_match_passed',
                    'name_match_checked_at',
                ]
            )
            _audit(
                user,
                VerificationAuditLog.Step.BANK,
                VerificationAuditLog.Status.FAILED,
                message=str(exc),
                response_meta={
                    'provider': bank_provider(),
                    'name_at_bank': result.get('name_at_bank', ''),
                    'name_match_score': float(profile.name_match_score),
                },
            )
            raise

    profile.account_holder_name = account_holder_name or result.get('name_at_bank', '')[:120]
    profile.bank_account_number = account_number
    profile.bank_ifsc = ifsc
    profile.bank_name = result.get('bank_name', '')[:120]
    profile.bank_branch = result.get('branch', '')[:120]
    profile.name_at_bank = result.get('name_at_bank', '')[:120]
    profile.bank_status = KycProfile.VerificationStatus.VERIFIED
    profile.bank_reference_id = result.get('reference_id', '')
    profile.bank_utr = result.get('utr', '')[:64]
    profile.bank_account_status = result.get('account_status', '')[:32]
    profile.bank_account_status_code = result.get('account_status_code', '')[:64]
    profile.bank_verification_method = result.get('verification_method', '')[:20]
    profile.bank_verified_at = timezone.now()
    profile.bank_failure_reason = ''
    profile.name_match_result = match_label
    profile.name_match_score = round(match_score * 100, 2)
    profile.name_match_passed = match_score >= NAME_MATCH_MIN_SCORE
    profile.name_match_checked_at = timezone.now()
    profile.save()
    _sync_bank_account(user, profile)
    _sync_user_name_from_kyc(user, profile)
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.BANK, VerificationAuditLog.Status.SUCCESS, response_meta={
        **result,
        'provider': bank_provider(),
        'provider_billed': True,
        'provider_reference_id': result.get('reference_id', ''),
    })
    return profile


def _resolve_upi_recipient_mobile(*, upi_vpa: str, recipient_mobile: str = '') -> str:
    explicit = normalize_phone(recipient_mobile)
    if explicit:
        return explicit
    return mobile_from_upi_vpa(upi_vpa)


def verify_upi_step(
    user,
    *,
    upi_vpa: str,
    recipient_mobile: str = '',
    latlong: str = '',
) -> KycProfile:
    upi_vpa = upi_vpa.strip().lower()
    if not UPI_VPA_REGEX.match(upi_vpa):
        raise ValueError('Enter a valid UPI ID (e.g. name@upi).')

    profile = get_or_create_profile(user)
    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('Verify PAN before UPI verification.')

    from .identity_review_service import IdentityReviewError, manual_upi_enabled, submit_manual_upi

    if manual_upi_enabled():
        if not _bank_ready_for_identity_steps(profile):
            if getattr(settings, 'KYC_BANK_REVIEW_MODE', 'provider') == 'manual':
                raise ValueError('Enter your bank account details before UPI verification.')
            raise ValueError(
                'Your bank account must be verified live before submitting UPI. '
                'Go back to Bank Verification and tap Verify Bank Account.'
            )
        linked_mobile = _resolve_upi_recipient_mobile(
            upi_vpa=upi_vpa,
            recipient_mobile=recipient_mobile,
        )
        try:
            return submit_manual_upi(user, upi_vpa=upi_vpa, upi_mobile=linked_mobile)
        except IdentityReviewError as exc:
            raise ValueError(str(exc)) from exc

    manual_review = getattr(settings, 'KYC_BANK_REVIEW_MODE', 'provider') == 'manual'
    if manual_review:
        if not profile.bank_account_number or not profile.bank_ifsc:
            raise ValueError('Enter your bank account details before UPI verification.')
        pending = (
            BankVerificationRequest.objects.filter(
                user=user,
                status=BankVerificationRequest.Status.PENDING,
            )
            .order_by('-submitted_at')
            .first()
        )
        if pending:
            raise ValueError(
                'Your bank and UPI details are already under review. Please wait for admin approval.'
            )
        linked_mobile = _resolve_upi_recipient_mobile(
            upi_vpa=upi_vpa,
            recipient_mobile=recipient_mobile,
        )
        from .bank_manual_service import ManualBankReviewError, submit_payment_review

        try:
            submit_payment_review(user, upi_vpa=upi_vpa, upi_mobile=linked_mobile)
        except ManualBankReviewError as exc:
            raise ValueError(str(exc)) from exc
        return get_or_create_profile(user)

    provider = upi_provider()
    if provider not in {'cashfree', 'eko'}:
        raise ValueError(f'UPI verification is not configured (KYC_UPI_PROVIDER={provider}).')

    if not _bank_really_verified(profile):
        raise ValueError('Verify bank account before UPI verification.')

    if _is_fake_verification_reference(profile.upi_reference_id):
        profile.upi_status = KycProfile.VerificationStatus.PENDING
        profile.upi_reference_id = ''
        profile.upi_verified_at = None
        profile.upi_failure_reason = ''
        profile.upi_vpa = ''
        profile.upi_name = ''
        profile.save(
            update_fields=[
                'upi_status',
                'upi_reference_id',
                'upi_verified_at',
                'upi_failure_reason',
                'upi_vpa',
                'upi_name',
            ]
        )

    pan_name = profile.pan_name or profile.account_holder_name or user.name
    bank_name = profile.name_at_bank or profile.account_holder_name or ''
    if not pan_name.strip():
        raise ValueError('Complete your profile name before UPI verification.')

    linked_mobile = _resolve_upi_recipient_mobile(
        upi_vpa=upi_vpa,
        recipient_mobile=recipient_mobile,
    )
    if provider == 'eko' and not linked_mobile:
        raise ValueError(
            'Enter the mobile number linked to this UPI ID when your UPI ID is not in phone@bank format.'
        )

    latlong = (latlong or DEFAULT_UPI_LATLONG).strip()

    verified_dob = _best_verified_dob(profile) or user.date_of_birth
    dob = verified_dob.isoformat() if verified_dob else ''

    _audit(
        user,
        VerificationAuditLog.Step.UPI,
        VerificationAuditLog.Status.STARTED,
        {'vpa': mask_upi_vpa(upi_vpa), 'linked_mobile': f'****{linked_mobile[-4:]}'},
    )

    if not _provider_configured_for('upi'):
        raise _provider_not_configured_error('upi')

    _assert_live_provider_verification_only('upi')

    try:
        result = _verify_upi(
            customer_vpa=upi_vpa,
            name=pan_name,
            recipient_mobile=linked_mobile,
            latlong=latlong,
            customer_id=user.phone or '',
            dob=dob,
            address={'city': user.city or ''},
        )
    except ProviderError as exc:
        profile.upi_status = KycProfile.VerificationStatus.FAILED
        profile.upi_failure_reason = str(exc)[:280]
        profile.save(update_fields=['upi_status', 'upi_failure_reason'])
        _audit(user, VerificationAuditLog.Step.UPI, VerificationAuditLog.Status.FAILED, message=str(exc))
        raise

    if result.get('dev_bypass'):
        profile.upi_status = KycProfile.VerificationStatus.FAILED
        profile.upi_failure_reason = (
            'UPI verification requires live Cashfree/Eko API access. Whitelist your server IP.'
        )[:280]
        profile.save(update_fields=['upi_status', 'upi_failure_reason'])
        raise CashfreeSecureIdError(profile.upi_failure_reason, 'dev_bypass_disabled')

    verified_name = (result.get('recipient_name') or '').strip()
    score_pan = _name_similarity(pan_name, verified_name)
    score_bank = _name_similarity(bank_name, verified_name) if bank_name else 0
    score = max(score_pan, score_bank)
    if score < 0.72:
        profile.upi_status = KycProfile.VerificationStatus.FAILED
        profile.upi_vpa = upi_vpa
        profile.upi_name = verified_name[:120]
        profile.upi_mobile = (result.get('mobile_number') or linked_mobile or '')[:15]
        profile.upi_name_match_score = round(score * 100, 2)
        profile.upi_failure_reason = (
            'UPI payee name does not match your verified PAN or bank account name.'
        )[:280]
        profile.save()
        _audit(
            user,
            VerificationAuditLog.Step.UPI,
            VerificationAuditLog.Status.FAILED,
            response_meta={'score': float(profile.upi_name_match_score), 'name': verified_name},
            message=profile.upi_failure_reason,
        )
        raise ValueError(profile.upi_failure_reason)

    profile.upi_vpa = upi_vpa
    profile.upi_name = verified_name[:120]
    profile.upi_mobile = (result.get('mobile_number') or linked_mobile or '')[:15]
    profile.upi_status = KycProfile.VerificationStatus.VERIFIED
    profile.upi_reference_id = result.get('reference_id', '')[:512]
    profile.upi_name_match_score = round(score * 100, 2)
    profile.upi_verified_at = timezone.now()
    profile.upi_failure_reason = ''
    profile.save()
    _sync_user_name_from_kyc(user, profile)
    _update_overall_status(profile)
    _audit(user, VerificationAuditLog.Step.UPI, VerificationAuditLog.Status.SUCCESS, response_meta={
        **result,
        'provider': upi_provider(),
        'provider_billed': True,
        'provider_reference_id': result.get('reference_id', ''),
    })
    return profile


def name_match_step(user) -> KycProfile:
    profile = get_or_create_profile(user)
    _audit(user, VerificationAuditLog.Step.NAME_MATCH, VerificationAuditLog.Status.STARTED)

    if profile.pan_status != KycProfile.VerificationStatus.VERIFIED:
        raise ValueError('PAN must be verified first.')
    if not _bank_really_verified(profile):
        raise ValueError('Bank must be verified first.')
    if upi_step_required() and not _upi_really_verified(profile):
        raise ValueError('Verify UPI before name match.')
    if not _selfie_really_verified(profile):
        raise ValueError('Selfie must be verified before name match.')

    pan_name = profile.pan_name or profile.account_holder_name
    bank_name = profile.name_at_bank or profile.account_holder_name
    score = _name_similarity(pan_name, bank_name)

    if score >= 0.72:
        result_label = 'DIRECT_MATCH' if score >= 0.92 else 'GOOD_PARTIAL_MATCH'
        profile.name_match_result = result_label
        profile.name_match_score = round(score * 100, 2)
        profile.name_match_passed = True
    else:
        profile.name_match_result = 'NO_MATCH'
        profile.name_match_score = round(score * 100, 2)
        profile.name_match_passed = False

    profile.name_match_checked_at = timezone.now()
    profile.save()
    _sync_user_name_from_kyc(user, profile)
    _update_overall_status(profile)

    status = (
        VerificationAuditLog.Status.SUCCESS
        if profile.name_match_passed
        else VerificationAuditLog.Status.FAILED
    )
    _audit(
        user,
        VerificationAuditLog.Step.NAME_MATCH,
        status,
        response_meta={'score': profile.name_match_score, 'result': profile.name_match_result},
    )
    return profile


def _sync_bank_account(user, profile: KycProfile):
    BankAccount.objects.update_or_create(
        user=user,
        defaults={
            'account_holder_name': profile.account_holder_name,
            'bank_name': profile.bank_name,
            'account_number': profile.bank_account_number,
            'ifsc': profile.bank_ifsc,
            'pan_number': profile.pan_number,
            'is_verified': profile.name_match_passed and _bank_really_verified(profile),
            'verification_provider': bank_provider(),
            'verification_status': 'verified' if _bank_really_verified(profile) else 'pending',
            'name_at_bank': profile.name_at_bank,
            'name_match_result': profile.name_match_result,
            'pan_registered_name': profile.pan_name,
            'verified_at': profile.bank_verified_at,
        },
    )


def _update_overall_status(profile: KycProfile):
    user = profile.user
    from .identity_review_service import identity_review_pending, manual_final_approval_required

    aadhaar_required = aadhaar_provider() == 'eko'
    aadhaar_verified = profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED
    aadhaar_failed = aadhaar_required and profile.aadhaar_status == KycProfile.VerificationStatus.FAILED
    aadhaar_ok = (not aadhaar_required) or aadhaar_verified
    upi_required = upi_step_required()
    upi_verified = _upi_really_verified(profile)
    upi_failed = upi_required and profile.upi_status == KycProfile.VerificationStatus.FAILED
    upi_ok = (not upi_required) or upi_verified
    manual_pending = identity_review_pending(profile)
    final_required = manual_final_approval_required()

    core_automated_ok = (
        profile.mobile_verified
        and _pan_really_verified(profile)
        and aadhaar_ok
        and _bank_really_verified(profile)
    )
    identity_ok = upi_ok and _selfie_really_verified(profile)
    final_ok = profile.name_match_passed if final_required else True

    if core_automated_ok and identity_ok and final_ok and (
        not final_required or profile.final_kyc_approved_at
    ):
        profile.overall_status = KycProfile.OverallStatus.VERIFIED
        profile.verified_at = profile.verified_at or timezone.now()
    elif (
        profile.pan_status == KycProfile.VerificationStatus.FAILED
        or profile.bank_status == KycProfile.VerificationStatus.FAILED
        or aadhaar_failed
        or upi_failed
        or profile.selfie_status == KycProfile.SelfieStatus.REJECTED
    ):
        profile.overall_status = KycProfile.OverallStatus.REJECTED
    elif profile.name_match_checked_at and not profile.name_match_passed and not manual_pending:
        profile.overall_status = KycProfile.OverallStatus.REJECTED
    elif manual_pending or (
        core_automated_ok
        and identity_ok
        and final_required
        and not profile.final_kyc_approved_at
    ):
        profile.overall_status = KycProfile.OverallStatus.UNDER_REVIEW
    else:
        profile.overall_status = KycProfile.OverallStatus.PENDING

    _sync_user_name_from_kyc(user, profile)
    _sync_user_kyc_from_profile(user, profile)
    profile.save()
    user.save(update_fields=['kyc_status', 'pan_status'])


def _sync_user_kyc_from_profile(user, profile: KycProfile):
    """Keep User.pan_status / User.kyc_status aligned with KycProfile for admin + app."""
    verified = KycProfile.VerificationStatus.VERIFIED
    failed = KycProfile.VerificationStatus.FAILED

    if profile.pan_status == verified:
        user.pan_status = User.PanStatus.VERIFIED
    elif profile.pan_status == failed:
        user.pan_status = User.PanStatus.REJECTED

    overall = profile.overall_status
    if overall == KycProfile.OverallStatus.VERIFIED:
        user.kyc_status = User.KycStatus.COMPLETED
        user.pan_status = User.PanStatus.VERIFIED
    elif overall == KycProfile.OverallStatus.REJECTED:
        user.kyc_status = User.KycStatus.REJECTED
    elif overall == KycProfile.OverallStatus.UNDER_REVIEW:
        user.kyc_status = User.KycStatus.IN_PROGRESS
    elif overall == KycProfile.OverallStatus.PENDING:
        if (
            profile.pan_status == verified
            or profile.bank_status == verified
            or profile.aadhaar_status == verified
        ):
            user.kyc_status = User.KycStatus.IN_PROGRESS
        elif profile.pan_status == failed:
            user.kyc_status = User.KycStatus.REJECTED
        else:
            user.kyc_status = User.KycStatus.PENDING


def user_dob_verified_from_kyc(user) -> bool:
    try:
        profile = user.kyc_profile
    except KycProfile.DoesNotExist:
        return False
    verified = KycProfile.VerificationStatus.VERIFIED
    return bool(
        (profile.pan_status == verified and profile.pan_dob)
        or (profile.aadhaar_status == verified and profile.aadhaar_dob)
    )


def _pan_really_verified(profile: KycProfile) -> bool:
    return (
        profile.pan_status == KycProfile.VerificationStatus.VERIFIED
        and not _is_fake_verification_reference(profile.pan_reference_id)
    )


def _bank_really_verified(profile: KycProfile) -> bool:
    """True only when a live provider confirmed the bank account."""
    return (
        profile.bank_status == KycProfile.VerificationStatus.VERIFIED
        and not _is_fake_verification_reference(profile.bank_reference_id)
    )


def _bank_ready_for_identity_steps(profile: KycProfile) -> bool:
    """Bank gate for manual UPI/selfie — live verify or saved draft (manual bank mode)."""
    if _bank_really_verified(profile):
        return True
    if getattr(settings, 'KYC_BANK_REVIEW_MODE', 'provider') != 'manual':
        return False
    return bool(
        profile.bank_account_number
        and profile.bank_ifsc
        and profile.bank_status != KycProfile.VerificationStatus.FAILED
    )


def _upi_really_verified(profile: KycProfile) -> bool:
    return (
        profile.upi_status == KycProfile.VerificationStatus.VERIFIED
        and not _is_fake_verification_reference(profile.upi_reference_id)
    )


def _selfie_really_verified(profile: KycProfile) -> bool:
    return profile.selfie_status == KycProfile.SelfieStatus.VERIFIED


def _bank_verification_logs(user, *, limit: int = 5) -> list[dict]:
    rows = VerificationAuditLog.objects.filter(
        user=user,
        step=VerificationAuditLog.Step.BANK,
    ).order_by('-created_at')[: max(1, limit)]
    logs = []
    for row in rows:
        req = row.request_meta or {}
        logs.append(
            {
                'time': row.created_at.isoformat(),
                'status': row.status,
                'message': row.message or '',
                'accountMasked': req.get('account', ''),
                'ifsc': req.get('ifsc', ''),
            }
        )
    return logs


def build_status_payload(profile: KycProfile) -> dict:
    from .identity_review_service import (
        identity_review_pending,
        manual_final_approval_required,
        manual_upi_enabled,
    )

    bank_review = (
        BankVerificationRequest.objects.filter(user=profile.user)
        .exclude(status=BankVerificationRequest.Status.SUPERSEDED)
        .order_by('-submitted_at')
        .first()
    )
    review_mode = getattr(settings, 'KYC_BANK_REVIEW_MODE', 'provider')
    bank_logs = _bank_verification_logs(profile.user)
    if review_mode == 'manual':
        bank_logs = [
            row
            for row in bank_logs
            if row.get('status', '').lower() in {'started', 'success'}
            or 'manual' in (row.get('message') or '').lower()
        ]
        if bank_review and bank_review.status == BankVerificationRequest.Status.PENDING:
            bank_logs = bank_logs[:1]
    return {
        'provider': _kyc_provider(),
        'kycMode': kyc_mode(),
        'upiRequired': upi_step_required(),
        'stepProviders': step_providers_payload(),
        'mobileVerified': profile.mobile_verified,
        'panVerified': _pan_really_verified(profile),
        'aadhaarVerified': profile.aadhaar_status == KycProfile.VerificationStatus.VERIFIED,
        'bankVerified': _bank_really_verified(profile),
        'bankReadyForIdentity': _bank_ready_for_identity_steps(profile),
        'selfieVerified': _selfie_really_verified(profile),
        'selfieStatus': profile.selfie_status,
        'selfieUrl': (
            profile.selfie_image.url
            if profile.selfie_image and profile.selfie_status != KycProfile.SelfieStatus.PENDING
            else ''
        ),
        'selfieReviewPending': profile.selfie_status == KycProfile.SelfieStatus.COMPLETED,
        'selfieReviewMessage': (
            'Your selfie has been submitted. Our team will manually verify it — please allow up to 24 hours.'
            if profile.selfie_status == KycProfile.SelfieStatus.COMPLETED
            else (
                profile.selfie_review_note
                if profile.selfie_status == KycProfile.SelfieStatus.REJECTED
                else ''
            )
        ),
        'selfieReviewDueAt': (
            profile.selfie_review_due_at.isoformat() if profile.selfie_review_due_at else None
        ),
        'nameMatchPassed': profile.name_match_passed,
        'overallStatus': profile.overall_status,
        'identityReviewPending': identity_review_pending(profile),
        'manualFinalApprovalRequired': manual_final_approval_required(),
        'finalKycApproved': bool(profile.final_kyc_approved_at),
        'upiManual': manual_upi_enabled(),
        'panNumberMasked': mask_pan(profile.pan_number) if profile.pan_number else '',
        'panName': profile.pan_name,
        'panStatus': profile.pan_status,
        'aadhaarNumberMasked': mask_aadhaar(profile.aadhaar_last4) if profile.aadhaar_last4 else '',
        'aadhaarName': profile.aadhaar_name,
        'aadhaarStatus': profile.aadhaar_status,
        'aadhaarVerificationMethod': 'digilocker',
        'aadhaarDigiLockerPending': (
            bool(profile.aadhaar_reference_id)
            and profile.aadhaar_status == KycProfile.VerificationStatus.PENDING
        ),
        'aadhaarDigiLockerUrl': (
            profile.aadhaar_digilocker_url
            if profile.aadhaar_status == KycProfile.VerificationStatus.PENDING
            else ''
        ),
        # Deprecated fields retained for old app builds; Eko no longer
        # supports its Aadhaar OTP product.
        'aadhaarOtpSent': False,
        'aadhaarRequiresSenderOtp': False,
        'bankName': profile.bank_name,
        'bankBranch': profile.bank_branch,
        'accountHolderName': profile.account_holder_name,
        'bankAccountMasked': mask_account_number(profile.bank_account_number),
        'ifsc': profile.bank_ifsc,
        'bankStatus': profile.bank_status,
        'bankFailureReason': (
            ''
            if bank_review and bank_review.status == BankVerificationRequest.Status.PENDING
            else profile.bank_failure_reason or ''
        ),
        'bankVerificationLogs': bank_logs,
        'bankVerificationMethod': profile.bank_verification_method,
        'bankSkipIdentityMatch': _bank_skip_identity_match(),
        'bankReviewMode': review_mode,
        'bankReviewStatus': bank_review.status if bank_review else '',
        'bankDraftReady': (
            review_mode == 'manual'
            and bool(profile.bank_account_number)
            and not _bank_really_verified(profile)
            and not (bank_review and bank_review.status == BankVerificationRequest.Status.PENDING)
        ),
        'paymentReviewPending': bool(
            bank_review and bank_review.status == BankVerificationRequest.Status.PENDING
        ),
        'bankReviewMessage': (
            'Your bank account and UPI ID are under manual review. Final verification may take up to 24 hours.'
            if bank_review and bank_review.status == BankVerificationRequest.Status.PENDING
            else (
                bank_review.review_note
                if bank_review and bank_review.status == BankVerificationRequest.Status.REJECTED
                else ''
            )
        ),
        'bankReviewDueAt': bank_review.review_due_at.isoformat() if bank_review else None,
        'upiVerified': _upi_really_verified(profile),
        'upiVpaMasked': mask_upi_vpa(profile.upi_vpa) if profile.upi_vpa else '',
        'upiName': profile.upi_name,
        'upiStatus': profile.upi_status,
        'upiFailureReason': (
            ''
            if bank_review and bank_review.status == BankVerificationRequest.Status.PENDING
            else profile.upi_failure_reason or ''
        ),
        'upiNameMatchScore': float(profile.upi_name_match_score or 0),
        'upiVerificationMethod': (
            'dev_bypass' if _is_fake_verification_reference(profile.upi_reference_id) else upi_provider()
        ),
        'nameAtBank': profile.name_at_bank,
        'nameMatchResult': profile.name_match_result,
        'nameMatchScore': float(profile.name_match_score or 0),
        'verifiedUserName': profile.user.name,
        'verifiedDob': profile.user.date_of_birth.isoformat() if profile.user.date_of_birth else None,
        'dobVerifiedFromKyc': user_dob_verified_from_kyc(profile.user),
        'verifiedAt': profile.verified_at.isoformat() if profile.verified_at else None,
        'cashfreeSandbox': (
            bank_provider() == 'cashfree' and not cashfree_settings().is_production
        ),
        'bankVerificationProvider': bank_provider(),
        'upiVerificationProvider': upi_provider(),
        'sandboxTestBank': (
            {
                'successAccountNumber': '026291800001191',
                'successIfsc': 'YESB0000262',
                'invalidAccountNumber': '026291800001190',
                'invalidIfsc': 'CNRR0002640',
            }
            if bank_provider() == 'cashfree' and not cashfree_settings().is_production
            else None
        ),
        'ekoBilling': eko_kyc_billing_status() if aadhaar_provider() == 'eko' or pan_provider() == 'eko' else None,
    }
