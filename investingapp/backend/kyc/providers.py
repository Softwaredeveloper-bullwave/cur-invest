"""Per-step KYC provider resolution with KYC_PROVIDER backward compatibility."""

from django.conf import settings

SUPPORTED_PROVIDERS = frozenset({'cashfree', 'eko'})


def legacy_kyc_provider() -> str:
    return (getattr(settings, 'KYC_PROVIDER', 'cashfree') or 'cashfree').strip().lower()


def step_provider(step: str) -> str:
    """Return provider for pan | bank | upi | aadhaar."""
    key = f'KYC_{step.strip().upper()}_PROVIDER'
    explicit = (getattr(settings, key, '') or '').strip().lower()
    if explicit:
        return explicit
    return legacy_kyc_provider()


def pan_provider() -> str:
    return step_provider('pan')


def bank_provider() -> str:
    return step_provider('bank')


def upi_provider() -> str:
    return step_provider('upi')


def aadhaar_provider() -> str:
    return step_provider('aadhaar')


def step_providers_payload() -> dict:
    return {
        'pan': pan_provider(),
        'bank': bank_provider(),
        'upi': upi_provider(),
        'aadhaar': aadhaar_provider(),
        'legacy': legacy_kyc_provider(),
    }


def _has_per_step_overrides() -> bool:
    return any(
        (getattr(settings, f'KYC_{step.upper()}_PROVIDER', '') or '').strip()
        for step in ('pan', 'bank', 'upi', 'aadhaar')
    )


def kyc_mode() -> str:
    """automated = Eko/Cashfree step flow; manual = document upload review."""
    if (
        aadhaar_provider() == 'eko'
        or pan_provider() == 'eko'
        or bank_provider() == 'eko'
        or _has_per_step_overrides()
    ):
        return 'automated'
    return 'manual'


def upi_step_required() -> bool:
    if getattr(settings, 'KYC_UPI_MANUAL', False):
        return True
    if not getattr(settings, 'KYC_UPI_REQUIRED', False):
        return False
    return upi_provider() in SUPPORTED_PROVIDERS
