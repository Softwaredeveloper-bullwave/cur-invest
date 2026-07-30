"""Eko Bank Verification — LIVE penniless / penny-drop integration.

Successful verification requires ALL of:
  response_status_id == 0
  status == 0
  account_status == VALID
  account_status_code == ACCOUNT_IS_VALID
"""

from __future__ import annotations

import logging
import re
import uuid
from difflib import SequenceMatcher

from services.eko_client import EkoTransportError, eko_post_json
from services.providers.eko_config import eko_settings

logger = logging.getLogger('bullwave.kyc')

BANK_VERIFY_PENNY_DROP_PATH = '/v3/tools/kyc/bank-account/sync'
NAME_MATCH_MIN_SCORE = 0.72


def _mask_account(account: str) -> str:
    acct = (account or '').strip()
    if len(acct) <= 4:
        return '****'
    return f'****{acct[-4:]}'


class EkoBankError(Exception):
    """Bank verification failure."""

    def __init__(self, message, code='', *, eko_meta=None):
        super().__init__(message)
        self.code = code
        self.eko_meta = eko_meta or {}


def _loose_match(a: str, b: str) -> bool:
    a = re.sub(r'[^A-Z0-9 ]', '', (a or '').upper()).strip()
    b = re.sub(r'[^A-Z0-9 ]', '', (b or '').upper()).strip()
    return bool(a) and bool(b) and a == b


def _name_similarity(a: str, b: str) -> float:
    if not a or not b:
        return 0.0
    left = re.sub(r'[^A-Z0-9 ]', '', a.upper()).strip()
    right = re.sub(r'[^A-Z0-9 ]', '', b.upper()).strip()
    return SequenceMatcher(None, left, right).ratio()


def _assert_submitted_name_matches_bank(account_holder_name: str, name_at_bank: str) -> None:
    from django.conf import settings

    if getattr(settings, 'KYC_BANK_SKIP_IDENTITY_MATCH', False):
        return
    submitted = (account_holder_name or '').strip()
    if not submitted:
        return
    if _name_similarity(submitted, name_at_bank) < NAME_MATCH_MIN_SCORE:
        raise EkoBankError(
            'The account holder name you entered does not match the name registered with this bank account.',
            'name_mismatch',
        )


def _should_fallback_to_penny_drop(exc: EkoBankError) -> bool:
    message = str(exc).lower()
    code = (exc.code or '').lower()
    if code in ('invalid_account', 'auth_failed'):
        return False
    if 'invalid ifsc' in message or 'account numbers do not match' in message:
        return False
    if code in (
        'penniless_unavailable',
        'penniless_not_enabled',
        'bank_product_not_ready',
        'service_not_active',
        'route_not_found',
        '403',
        'network_error',
        'timeout',
    ):
        return True
    if 'pennyless' in message and any(
        token in message for token in ('not enabled', 'not available', 'use penny', 'penny drop')
    ):
        return True
    if any(
        token in message
        for token in (
            'unsupported api route',
            'does not know this ditty',
            '404',
            'rejected the request',
            'credential scope',
            'invalid or unsupported api route',
        )
    ):
        return True
    return False


def is_bank_verification_successful(envelope: dict, data: dict) -> tuple[bool, str]:
    """Return ``(True, '')`` only when Eko reports a fully valid account."""
    rsid = envelope.get('response_status_id')
    status = envelope.get('status')
    message = (envelope.get('message') or data.get('message') or '').strip()

    if rsid is None or str(rsid) != '0':
        return False, message or 'Bank verification failed.'
    if status is None or str(status) != '0':
        return False, message or 'Bank verification failed.'

    account_status = (data.get('account_status') or '').strip().upper()
    account_status_code = (data.get('account_status_code') or '').strip().upper()
    if account_status != 'VALID':
        return False, message or f'Bank account status is {account_status or "unknown"}.'
    if account_status_code != 'ACCOUNT_IS_VALID':
        return False, message or f'Bank account status code is {account_status_code or "unknown"}.'

    return True, ''


def parse_bank_verification_fields(envelope: dict, data: dict, *, client_ref_id: str) -> dict:
    """Extract the fields required by the product from an Eko bank response."""
    ok, reason = is_bank_verification_successful(envelope, data)
    if not ok:
        raise EkoBankError(reason or 'Bank account could not be verified.', 'invalid_account')

    reference_id = str(
        data.get('reference_id')
        or data.get('transaction_id')
        or data.get('utr')
        or client_ref_id
        or ''
    )
    utr = str(data.get('utr') or '')
    name_at_bank = (
        data.get('name_at_bank')
        or data.get('account_name')
        or data.get('recipient_name')
        or data.get('beneficiary_name')
        or data.get('account_holder_name')
        or data.get('name')
        or ''
    ).strip()
    if not name_at_bank:
        raise EkoBankError(
            (envelope.get('message') or 'Bank verified but account holder name was missing.'),
            'invalid_account',
        )

    return {
        'reference_id': reference_id,
        'utr': utr,
        'account_status': (data.get('account_status') or 'VALID').strip().upper(),
        'account_status_code': (data.get('account_status_code') or 'ACCOUNT_IS_VALID').strip().upper(),
        'name_at_bank': name_at_bank,
        'bank_name': (data.get('bank_name') or data.get('bank') or '').strip(),
        'branch': (data.get('branch') or '').strip(),
        'verified': True,
        'provider_message': (envelope.get('message') or '').strip(),
    }


def _normalize_success(
    envelope: dict,
    data: dict,
    *,
    client_ref_id: str,
    verification_method: str,
    account_holder_name: str = '',
) -> dict:
    parsed = parse_bank_verification_fields(envelope, data, client_ref_id=client_ref_id)
    _assert_submitted_name_matches_bank(account_holder_name, parsed['name_at_bank'])
    matched = bool(account_holder_name) and _loose_match(account_holder_name, parsed['name_at_bank'])
    score = _name_similarity(account_holder_name, parsed['name_at_bank']) if account_holder_name else None
    return {
        **parsed,
        'verification_method': verification_method,
        'name_match_result': 'DIRECT_MATCH' if matched else 'GOOD_PARTIAL_MATCH',
        'name_match_score': round(score * 100, 2) if score is not None else None,
    }


def _penniless_paths(cfg) -> list[str]:
    if not cfg.penniless_configured:
        return []
    paths: list[str] = []
    if cfg.penniless_path:
        paths.append(cfg.penniless_path)
    if cfg.org_slug:
        slug_path = f'/v3/tools/kyc/{cfg.org_slug}/bank-acc-verify-penniless'
        if slug_path not in paths:
            paths.append(slug_path)
    return paths


def _penniless_payload(cfg, *, account_number: str, ifsc: str, client_ref_id: str) -> dict:
    return {
        'initiator_id': cfg.initiator_id,
        'user_code': cfg.user_code,
        'client_ref_id': client_ref_id,
        'account': account_number.strip(),
        'ifsc': ifsc.upper().strip(),
    }


def _penny_drop_attempts(cfg, *, account_number: str, ifsc: str, client_ref_id: str) -> list[tuple[str, dict]]:
    attempts: list[tuple[str, dict]] = []
    if cfg.org_slug:
        attempts.append(
            (
                f'/v3/tools/kyc/{cfg.org_slug}/bank-acc-verify-pennydrop',
                {
                    'initiator_id': cfg.initiator_id,
                    'user_code': cfg.user_code,
                    'client_ref_id': client_ref_id,
                    'account': account_number.strip(),
                    'ifsc': ifsc.upper().strip(),
                },
            )
        )
    attempts.append(
        (
            BANK_VERIFY_PENNY_DROP_PATH,
            {
                'initiator_id': cfg.initiator_id,
                'user_code': cfg.user_code,
                'client_ref_id': client_ref_id,
                'bank_account': account_number.strip(),
                'ifsc': ifsc.upper().strip(),
            },
        )
    )
    return attempts


def verify_bank_account_penniless(
    *,
    account_number: str,
    ifsc: str,
    account_holder_name: str = '',
) -> dict:
    cfg = eko_settings()
    client_ref_id = uuid.uuid4().hex[:20]
    paths = _penniless_paths(cfg)
    if not paths:
        raise EkoBankError(
            'Eko Penny-less path is not configured. Set EKO_ORG_SLUG or EKO_PENNYLESS_PATH.',
            'penniless_unavailable',
        )

    payload = _penniless_payload(cfg, account_number=account_number, ifsc=ifsc, client_ref_id=client_ref_id)
    last_exc: Exception | None = None
    for path in paths:
        logger.info(
            'Eko penniless verify account=%s ifsc=%s path=%s',
            _mask_account(account_number),
            ifsc.upper().strip(),
            path,
        )
        try:
            envelope, data = eko_post_json(path, payload, mask_account=_mask_account)
            return _normalize_success(
                envelope,
                data,
                client_ref_id=client_ref_id,
                verification_method='penniless',
                account_holder_name=account_holder_name,
            )
        except (EkoBankError, EkoTransportError) as exc:
            bank_exc = exc if isinstance(exc, EkoBankError) else EkoBankError(str(exc), getattr(exc, 'code', ''))
            if not _should_fallback_to_penny_drop(bank_exc):
                raise bank_exc from exc
            last_exc = bank_exc
            logger.warning('Eko penniless path %s unavailable: %s', path, exc)

    if last_exc:
        last_exc.code = last_exc.code or 'penniless_unavailable'
        raise last_exc
    raise EkoBankError('Eko Penny-less verification is unavailable.', 'penniless_unavailable')


def verify_bank_account_penny_drop(
    *,
    account_number: str,
    ifsc: str,
    account_holder_name: str = '',
) -> dict:
    cfg = eko_settings()
    client_ref_id = uuid.uuid4().hex[:20]
    logger.info(
        'Eko penny-drop verify account=%s ifsc=%s',
        _mask_account(account_number),
        ifsc.upper().strip(),
    )
    last_exc: Exception | None = None
    for path, payload in _penny_drop_attempts(
        cfg,
        account_number=account_number,
        ifsc=ifsc,
        client_ref_id=client_ref_id,
    ):
        try:
            envelope, data = eko_post_json(path, payload, mask_account=_mask_account)
            return _normalize_success(
                envelope,
                data,
                client_ref_id=client_ref_id,
                verification_method='penny_drop',
                account_holder_name=account_holder_name,
            )
        except (EkoBankError, EkoTransportError) as exc:
            bank_exc = exc if isinstance(exc, EkoBankError) else EkoBankError(str(exc), getattr(exc, 'code', ''))
            if bank_exc.code == 'invalid_account' or not _should_fallback_to_penny_drop(bank_exc):
                raise bank_exc from exc
            last_exc = bank_exc
            logger.warning('Eko penny-drop path %s unavailable: %s', path, exc)

    if last_exc:
        raise last_exc
    raise EkoBankError('Penny-drop verification is not configured.', 'penny_drop_unavailable')


def verify_bank_account(
    *,
    account_number: str,
    ifsc: str,
    account_holder_name: str = '',
    **legacy_kwargs,
) -> dict:
    """Verify a bank account via Eko LIVE API (penniless first, penny-drop fallback)."""
    _ = legacy_kwargs  # phone, dob, address — retained for callers
    cfg = eko_settings()
    penniless_error: EkoBankError | None = None

    if cfg.penniless_enabled and cfg.penniless_configured:
        try:
            return verify_bank_account_penniless(
                account_number=account_number,
                ifsc=ifsc,
                account_holder_name=account_holder_name,
            )
        except EkoBankError as exc:
            if exc.code == 'invalid_account':
                raise
            penniless_error = exc
            logger.warning('Eko penniless unavailable, falling back to penny-drop: %s', exc)

    try:
        return verify_bank_account_penny_drop(
            account_number=account_number,
            ifsc=ifsc,
            account_holder_name=account_holder_name,
        )
    except EkoBankError:
        if penniless_error:
            raise penniless_error
        raise
