"""Encryption helpers for Aadhaar numbers held during an OTP transaction."""

import base64
import hashlib
import re

from cryptography.fernet import Fernet, InvalidToken
from django.conf import settings


def _fernet() -> Fernet:
    configured_key = (getattr(settings, 'AADHAAR_ENCRYPTION_KEY', '') or '').strip()
    if configured_key:
        return Fernet(configured_key.encode())

    # This fallback keeps local development usable. Production must set a
    # dedicated key so SECRET_KEY rotation does not invalidate pending OTPs.
    if not settings.DEBUG:
        raise RuntimeError('AADHAAR_ENCRYPTION_KEY must be configured in production.')
    derived = hashlib.sha256(settings.SECRET_KEY.encode()).digest()
    return Fernet(base64.urlsafe_b64encode(derived))


def encrypt_aadhaar(value: str) -> str:
    digits = re.sub(r'\D', '', value or '')
    if len(digits) != 12:
        raise ValueError('Aadhaar number must be 12 digits.')
    return _fernet().encrypt(digits.encode()).decode()


def decrypt_aadhaar(value: str) -> str:
    stored = (value or '').strip()
    # Backward compatibility for an in-flight OTP created before encryption
    # was introduced. Verified legacy values are removed by migration 0010.
    if re.fullmatch(r'\d{12}', stored):
        return stored
    if not stored:
        return ''
    try:
        decrypted = _fernet().decrypt(stored.encode()).decode()
    except (InvalidToken, ValueError) as exc:
        raise ValueError('The pending Aadhaar verification session is invalid. Start again.') from exc
    if not re.fullmatch(r'\d{12}', decrypted):
        raise ValueError('The pending Aadhaar verification session is invalid. Start again.')
    return decrypted
