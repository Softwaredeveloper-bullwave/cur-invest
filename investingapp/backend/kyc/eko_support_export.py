"""Build a sanitized support log bundle for Eko Connect (email attachment)."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from django.conf import settings

from accounts.models import User
from kyc.masking import mask_account_number
from kyc.models import KycProfile, VerificationAuditLog
from kyc.providers import bank_provider, step_providers_payload
from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import eko_kyc_billing_status


_BANK_LOG_KEYWORDS = re.compile(
    r'bank|penny|penniless|verify-bank|bank-account|bank_acc|kyc/bank',
    re.IGNORECASE,
)


def _json_block(data) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False, default=str)


def _read_log_excerpt(log_path: Path, *, max_lines: int = 400) -> list[str]:
    if not log_path.is_file():
        return []
    try:
        lines = log_path.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError:
        return []
    matched = [line for line in lines if _BANK_LOG_KEYWORDS.search(line)]
    if not matched:
        matched = lines[-max_lines:]
    else:
        matched = matched[-max_lines:]
    return matched


def _audit_rows_for_user(user: User, *, limit: int = 50) -> list[VerificationAuditLog]:
    return list(
        VerificationAuditLog.objects.filter(
            user=user,
            step=VerificationAuditLog.Step.BANK,
        ).order_by('-created_at')[: max(1, limit)]
    )


def _audit_rows_global(*, limit: int = 30) -> list[VerificationAuditLog]:
    return list(
        VerificationAuditLog.objects.filter(
            step=VerificationAuditLog.Step.BANK,
        ).order_by('-created_at')[: max(1, limit)]
    )


def build_eko_support_report(
    *,
    phone: str = '',
    audit_limit: int = 50,
    log_line_limit: int = 400,
    include_global_audit: bool = False,
) -> str:
    """Return plain-text report safe to email Eko (no API secrets)."""
    now = datetime.now(timezone.utc)
    cfg = eko_settings()
    providers = step_providers_payload()
    billing = eko_kyc_billing_status()
    log_file = (getattr(settings, 'EKO_API_LOG_FILE', '') or '').strip()
    log_path = Path(log_file) if log_file else Path('logs/eko_kyc.log')

    user = None
    profile = None
    if phone:
        user = User.objects.filter(phone=phone).first()
        if user:
            profile = KycProfile.objects.filter(user=user).first()

    lines: list[str] = [
        'EKO CONNECT — BANK VERIFICATION SUPPORT LOG EXPORT',
        f'Generated (UTC): {now.isoformat()}',
        'Application: BullWave Capital (investing app KYC)',
        '',
        '=== MERCHANT CONFIGURATION (secrets redacted) ===',
        f'KYC_BANK_PROVIDER          : {bank_provider()}',
        f'Step providers             : {_json_block(providers)}',
        f'EKO_ENVIRONMENT            : {cfg.environment}',
        f'EKO_BASE_URL               : {cfg.base_url or "(not set)"}',
        f'EKO_INITIATOR_ID           : {cfg.initiator_id or "(not set)"}',
        f'EKO_USER_CODE              : {cfg.user_code or "(not set)"}',
        f'EKO_DEVELOPER_KEY          : {"set" if cfg.developer_key else "MISSING"}',
        f'EKO_ACCESS_KEY             : {"set" if cfg.access_key else "MISSING"}',
        f'EKO_ORG_SLUG               : {cfg.org_slug or "(empty — penniless disabled)"}',
        f'EKO_PENNILESS_ENABLED      : {cfg.penniless_enabled}',
        f'EKO_PENNYLESS_PATH         : {cfg.penniless_path or "(auto from slug)"}',
        f'EKO configured             : {cfg.is_configured}',
        '',
        '=== EKO BANK API ENDPOINTS (expected) ===',
    ]

    bank_info = (billing.get('steps') or {}).get('bank') or {}
    for key in ('api', 'walletLabel', 'activate'):
        if bank_info.get(key):
            lines.append(f'{key}: {bank_info[key]}')

    lines.extend(['', '=== ISSUE SUMMARY ==='])
    if not phone:
        lines.append('No user phone filter — merchant-wide export.')
    elif not user:
        lines.append(f'User phone {phone}: NOT FOUND in database.')
    else:
        lines.append(f'User phone                 : {user.phone}')
        lines.append(f'User name                  : {user.name or "(blank)"}')
        if profile:
            lines.extend(
                [
                    f'Bank status                : {profile.bank_status}',
                    f'Bank verification method   : {profile.bank_verification_method or "(none)"}',
                    f'Last failure reason        : {profile.bank_failure_reason or "(none)"}',
                    f'Account (masked)           : {mask_account_number(profile.bank_account_number)}',
                    f'IFSC                       : {profile.bank_ifsc or "(none)"}',
                    f'Bank reference id          : {profile.bank_reference_id or "(none)"}',
                ]
            )
        else:
            lines.append('KYC profile                : not created yet')

        rows = _audit_rows_for_user(user, limit=audit_limit)
        failed = sum(1 for r in rows if r.status == VerificationAuditLog.Status.FAILED)
        lines.extend(
            [
                f'Bank audit rows (exported) : {len(rows)}',
                f'Failed attempts in export  : {failed}',
            ]
        )

    lines.extend(['', '=== BANK VERIFICATION ATTEMPT TIMELINE ==='])
    if phone and user:
        audit_rows = _audit_rows_for_user(user, limit=audit_limit)
        if not audit_rows:
            lines.append('No bank verification attempts recorded for this user.')
        for idx, row in enumerate(audit_rows, start=1):
            lines.extend(
                [
                    f'--- Attempt #{idx} ---',
                    f'Timestamp (UTC)  : {row.created_at.isoformat()}',
                    f'Status           : {row.status}',
                    f'Message          : {row.message or "(empty)"}',
                    f'Request meta     : {_json_block(row.request_meta or {})}',
                    f'Response meta    : {_json_block(row.response_meta or {})}',
                    '',
                ]
            )
    elif include_global_audit:
        audit_rows = _audit_rows_global(limit=audit_limit)
        lines.append(f'Recent bank attempts (all users, max {audit_limit}):')
        for row in audit_rows:
            lines.append(
                f'  {row.created_at:%Y-%m-%d %H:%M:%S} UTC | phone={row.user.phone} | '
                f'{row.status} | {row.message[:200] if row.message else ""}'
            )
            if row.request_meta:
                lines.append(f'    request: {_json_block(row.request_meta)}')
            if row.response_meta:
                lines.append(f'    response: {_json_block(row.response_meta)}')
    else:
        lines.append('Pass --phone to include per-user attempt timeline.')

    lines.extend(['=== EKO HTTP LOG EXCERPT ==='])
    log_lines = _read_log_excerpt(log_path, max_lines=log_line_limit)
    if log_lines:
        lines.append(f'Source: {log_path.resolve()}')
        lines.append(f'Lines included: {len(log_lines)} (bank-related filter, else tail)')
        lines.append('')
        lines.extend(log_lines)
    else:
        lines.extend(
            [
                f'Log file not found or empty: {log_path.resolve()}',
                'To capture live Eko HTTP calls, add to backend/.env:',
                '  EKO_API_LOG_FILE=logs/eko_kyc.log',
                '  EKO_LOG_LEVEL=DEBUG',
                'Restart Django, retry bank verify, then re-run this export.',
            ]
        )

    lines.extend(
        [
            '',
            '=== SUPPORT REQUEST (copy into email body) ===',
            'Hi Eko Connect team,',
            '',
            'We are integrating Bank Account Verification (penny-less / penny-drop) via',
            f'{cfg.base_url} for merchant initiator_id={cfg.initiator_id}.',
            'Bank verification attempts are failing — please find attached logs.',
            '',
            'Please confirm:',
            '  1) Bank Verification product is enabled for our merchant account',
            '  2) Our EKO_ORG_SLUG for penniless route (if applicable)',
            '  3) Wallet balance / billing status for bank verification API',
            '  4) Reason for recent failures listed in the timeline above',
            '',
            'Thank you,',
            'BullWave Capital Engineering',
        ]
    )
    return '\n'.join(lines) + '\n'
