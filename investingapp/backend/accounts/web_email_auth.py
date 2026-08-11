"""Web signup: email OTP first (no auth), then phone OTP attaches the verified email."""

from __future__ import annotations

import logging
import random
import secrets
from datetime import timedelta

from django.conf import settings
from django.core import signing
from django.utils import timezone

from kyc.notifications import EmailDeliveryError, send_plain_email

from .email_otp_service import EmailOtpError, normalize_email, _EMAIL_REGEX, _delivery_mode
from .models import PendingEmailOTP, User

logger = logging.getLogger('bullwave.accounts')

EMAIL_PROOF_SALT = 'bullwave-web-email-proof'
EMAIL_PROOF_MAX_AGE = 30 * 60  # 30 minutes


def _issue_pending_otp(email: str) -> str:
    otp = f'{random.randint(100000, 999999):06d}'
    expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
    PendingEmailOTP.objects.filter(email=email, is_used=False).update(is_used=True)
    PendingEmailOTP.objects.create(email=email, otp_code=otp, expires_at=expires_at)
    return otp


def send_web_email_otp(email: str) -> dict:
    email = normalize_email(email)
    if not _EMAIL_REGEX.match(email):
        raise EmailOtpError('Enter a valid email address.', 'invalid_email')

    mode = _delivery_mode()
    if not mode:
        raise EmailOtpError(
            'Email OTP is unavailable. Configure Gmail SMTP in backend/.env and restart Django.',
            'email_not_configured',
        )

    otp = _issue_pending_otp(email)

    if mode == 'email':
        try:
            send_plain_email(
                to_email=email,
                subject='Your BullWave email verification code',
                text_body=(
                    f'Your BullWave verification code is {otp}.\n\n'
                    f'It expires in {settings.OTP_EXPIRY_MINUTES} minutes.\n\n'
                    'If you did not request this, you can ignore this email.'
                ),
            )
        except EmailDeliveryError as exc:
            logger.error('Web email OTP delivery failed for %s: %s', email, exc)
            detail = str(exc)
            if '535' in detail or 'BadCredentials' in detail or 'Username and Password not accepted' in detail:
                detail = (
                    'Gmail SMTP login failed. Set EMAIL_HOST_PASSWORD to a Gmail App Password '
                    'in investingapp/backend/.env, then restart Django.'
                )
            raise EmailOtpError(detail, 'email_delivery_failed') from exc

    logger.info('Web email OTP issued for %s mode=%s', email, mode)
    payload = {
        'success': True,
        'message': 'Verification code sent to your email.',
        'email': email,
        'otpMode': mode,
    }
    if mode == 'console':
        payload['message'] = 'Development email OTP generated without sending mail.'
        payload['devOtp'] = otp
    return payload


def apply_verified_email_to_user(user: User, email: str) -> User:
    """Attach a pre-verified email to the phone-authenticated user."""
    conflict = (
        User.objects.filter(email__iexact=email, email_verified=True)
        .exclude(pk=user.pk)
        .first()
    )
    if conflict:
        raise EmailOtpError(
            'This email is already linked to another account. Use a different email or sign in with that account.',
            'email_in_use',
        )

    user.email = email
    user.email_verified = True
    user.save(update_fields=['email', 'email_verified'])
    return user


def find_returning_web_user(email: str) -> User | None:
    """User who already linked this verified email + has a phone (full signup done once)."""
    email = normalize_email(email)
    if not _EMAIL_REGEX.match(email):
        return None
    user = (
        User.objects.filter(email__iexact=email, email_verified=True)
        .exclude(phone='')
        .first()
    )
    return user


def issue_email_proof_payload(email: str) -> dict:
    email = normalize_email(email)
    token = signing.dumps({'email': email, 'nonce': secrets.token_hex(8)}, salt=EMAIL_PROOF_SALT)
    return {'emailProofToken': token}


def resolve_email_proof_token(token: str) -> str:
    if not token:
        raise EmailOtpError('Email verification expired. Verify your email again.', 'email_proof_missing')
    try:
        payload = signing.loads(token, salt=EMAIL_PROOF_SALT, max_age=EMAIL_PROOF_MAX_AGE)
    except signing.SignatureExpired as exc:
        raise EmailOtpError('Email verification expired. Verify your email again.', 'email_proof_expired') from exc
    except signing.BadSignature as exc:
        raise EmailOtpError('Invalid email verification. Start again.', 'email_proof_invalid') from exc

    email = normalize_email(payload.get('email', '') if isinstance(payload, dict) else '')
    if not _EMAIL_REGEX.match(email):
        raise EmailOtpError('Invalid email verification. Start again.', 'email_proof_invalid')
    return email


def verify_web_email_otp(email: str, otp: str) -> dict:
    email = normalize_email(email)
    otp = (otp or '').strip()
    if not _EMAIL_REGEX.match(email):
        raise EmailOtpError('Enter a valid email address.', 'invalid_email')
    if len(otp) != 6 or not otp.isdigit():
        raise EmailOtpError('Enter the 6-digit verification code.', 'invalid_otp')

    latest = (
        PendingEmailOTP.objects.filter(
            email=email,
            is_used=False,
            expires_at__gte=timezone.now(),
        )
        .order_by('-created_at')
        .first()
    )
    if not latest:
        raise EmailOtpError('Verification code expired. Request a new code.', 'otp_expired')
    if latest.otp_code != otp:
        raise EmailOtpError('Incorrect verification code. Please try again.', 'invalid_otp')

    latest.is_used = True
    latest.save(update_fields=['is_used'])

    returning = find_returning_web_user(email)
    if returning:
        return {
            'success': True,
            'message': 'Welcome back.',
            'email': email,
            'nextStep': 'app' if returning.has_completed_onboarding else 'onboarding',
            'isReturningUser': True,
            'userId': str(returning.id),
        }

    return {
        'success': True,
        'message': 'Email verified. Continue with phone verification.',
        'email': email,
        'nextStep': 'phone',
        'isReturningUser': False,
        **issue_email_proof_payload(email),
    }
