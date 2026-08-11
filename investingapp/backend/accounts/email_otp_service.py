"""Email OTP verification — mirrors phone OTP using configured SMTP / providers."""

from __future__ import annotations

import logging
import random
import re
from datetime import timedelta

from django.conf import settings
from django.utils import timezone

from kyc.notifications import EmailDeliveryError, email_delivery_chain, send_plain_email

from .models import EmailOTPVerification, User

logger = logging.getLogger('bullwave.accounts')

_EMAIL_REGEX = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')


class EmailOtpError(Exception):
    def __init__(self, message: str, code: str = ''):
        super().__init__(message)
        self.code = code


def normalize_email(email: str) -> str:
    return (email or '').strip().lower()


def _delivery_mode() -> str:
    if email_delivery_chain():
        return 'email'
    if settings.DEBUG:
        return 'console'
    return ''


def _issue_local_otp(*, user: User, email: str) -> str:
    otp = f'{random.randint(100000, 999999):06d}'
    expires_at = timezone.now() + timedelta(minutes=settings.OTP_EXPIRY_MINUTES)
    EmailOTPVerification.objects.filter(user=user, email=email, is_used=False).update(is_used=True)
    EmailOTPVerification.objects.create(
        user=user,
        email=email,
        otp_code=otp,
        expires_at=expires_at,
    )
    return otp


def _ensure_email_available(user: User, email: str) -> None:
    if not _EMAIL_REGEX.match(email):
        raise EmailOtpError('Enter a valid email address.', 'invalid_email')
    taken = (
        User.objects.filter(email__iexact=email, email_verified=True)
        .exclude(pk=user.pk)
        .exists()
    )
    if taken:
        raise EmailOtpError('This email is already linked to another account.', 'email_in_use')


def send_email_otp(*, user: User, email: str) -> dict:
    email = normalize_email(email)
    _ensure_email_available(user, email)

    mode = _delivery_mode()
    if not mode:
        raise EmailOtpError(
            'Email OTP is unavailable. Configure Gmail SMTP or another email provider in .env.',
            'email_not_configured',
        )

    otp = _issue_local_otp(user=user, email=email)
    user.email = email
    user.email_verified = False
    user.save(update_fields=['email', 'email_verified'])

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
            logger.error('Email OTP delivery failed for user=%s: %s', user.pk, exc)
            detail = str(exc)
            if '535' in detail or 'BadCredentials' in detail or 'Username and Password not accepted' in detail:
                detail = (
                    'Gmail SMTP login failed. Set EMAIL_HOST_PASSWORD to a Gmail App Password '
                    '(Google Account → Security → App passwords), not a Brevo API key. Then restart Django.'
                )
            elif 'No email provider' in detail or 'not configured' in detail.lower():
                detail = (
                    'Gmail SMTP is not configured. Add EMAIL_HOST_USER and EMAIL_HOST_PASSWORD '
                    '(Gmail App Password) in investingapp/backend/.env and restart Django.'
                )
            raise EmailOtpError(detail, 'email_delivery_failed') from exc

    logger.info('Email OTP issued for user=%s mode=%s', user.pk, mode)
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


def verify_email_otp(*, user: User, email: str, otp: str) -> User:
    email = normalize_email(email)
    otp = (otp or '').strip()
    if len(otp) != 6 or not otp.isdigit():
        raise EmailOtpError('Enter the 6-digit verification code.', 'invalid_otp')

    _ensure_email_available(user, email)

    latest = (
        EmailOTPVerification.objects.filter(
            user=user,
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

    user.email = email
    user.email_verified = True
    user.save(update_fields=['email', 'email_verified'])
    return user
