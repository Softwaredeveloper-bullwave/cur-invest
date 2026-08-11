"""Google Sign-In for the website — verifies ID token, skips email OTP."""

from __future__ import annotations

import logging

from django.conf import settings

from .email_otp_service import normalize_email, _EMAIL_REGEX
from .models import User
from .web_email_auth import find_returning_web_user, issue_email_proof_payload

logger = logging.getLogger('bullwave.accounts')


class GoogleAuthError(Exception):
    def __init__(self, message: str, code: str = ''):
        super().__init__(message)
        self.code = code


def _client_id() -> str:
    return (getattr(settings, 'GOOGLE_OAUTH_CLIENT_ID', '') or '').strip()


def verify_google_id_token(id_token_str: str) -> dict:
    """Return {email, name, picture, sub} from a Google ID token."""
    token = (id_token_str or '').strip()
    if not token:
        raise GoogleAuthError('Missing Google credential.', 'missing_token')

    client_id = _client_id()
    if not client_id:
        raise GoogleAuthError(
            'Google Sign-In is not configured. Set GOOGLE_OAUTH_CLIENT_ID in backend/.env.',
            'not_configured',
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token
    except ImportError as exc:
        raise GoogleAuthError(
            'google-auth package is not installed. Run: pip install google-auth',
            'dependency_missing',
        ) from exc

    try:
        info = id_token.verify_oauth2_token(
            token,
            google_requests.Request(),
            audience=client_id,
        )
    except ValueError as exc:
        logger.warning('Google ID token verification failed: %s', exc)
        raise GoogleAuthError('Google sign-in failed. Try again or use email OTP.', 'invalid_token') from exc

    if info.get('iss') not in ('accounts.google.com', 'https://accounts.google.com'):
        raise GoogleAuthError('Invalid Google token issuer.', 'invalid_issuer')

    email = normalize_email(info.get('email', ''))
    if not _EMAIL_REGEX.match(email):
        raise GoogleAuthError('Google account did not return a valid email.', 'no_email')
    if not info.get('email_verified'):
        raise GoogleAuthError('Google email is not verified. Use another account or email OTP.', 'email_unverified')

    return {
        'email': email,
        'name': (info.get('name') or '').strip(),
        'picture': (info.get('picture') or '').strip(),
        'sub': str(info.get('sub') or ''),
    }


def authenticate_with_google(id_token_str: str) -> dict:
    """
    Verify Google credential.

    Returning users (email already linked + phone on file): nextStep=app|onboarding
    New users: emailProofToken + nextStep=phone
    """
    profile = verify_google_id_token(id_token_str)
    email = profile['email']
    name = profile['name']

    returning = find_returning_web_user(email)
    if returning:
        if name and not (returning.name or '').strip():
            returning.name = name
            returning.save(update_fields=['name'])
        return {
            'success': True,
            'provider': 'google',
            'email': email,
            'name': returning.name or name,
            'picture': profile.get('picture') or '',
            'message': 'Welcome back.',
            'nextStep': 'app' if returning.has_completed_onboarding else 'onboarding',
            'isReturningUser': True,
            'userId': str(returning.id),
        }

    return {
        'success': True,
        'provider': 'google',
        'email': email,
        'name': name,
        'picture': profile.get('picture') or '',
        'message': 'Google sign-in successful. Continue with phone verification.',
        'nextStep': 'phone',
        'isReturningUser': False,
        **issue_email_proof_payload(email),
    }
