"""Load all Eko Platform Services credentials from environment — never hardcode.

Paste your Eko keys in investingapp/backend/.env (see the EKO_* block) —
never commit real keys to git.
"""

from dataclasses import dataclass

from django.conf import settings


@dataclass(frozen=True)
class EkoSettings:
    developer_key: str
    access_key: str
    initiator_id: str
    user_code: str
    environment: str
    base_url: str
    org_slug: str
    penniless_enabled: bool
    penniless_path: str

    @property
    def is_configured(self) -> bool:
        return bool(
            self.developer_key
            and self.access_key
            and self.initiator_id
            and self.user_code
            and self.base_url
        )

    @property
    def is_production(self) -> bool:
        return self.environment.lower() in ('production', 'prod', 'live')

    @property
    def penniless_configured(self) -> bool:
        return bool(self.penniless_path)

    @property
    def http_timeout_seconds(self) -> float:
        return float(getattr(settings, 'EKO_HTTP_TIMEOUT_SECONDS', 90))


def _env(name: str, default: str = '') -> str:
    value = (getattr(settings, name, None) or default or '').strip()
    quotes = {'"', "'", '\u201c', '\u201d', '\u2018', '\u2019'}
    while len(value) >= 2 and value[0] in quotes and value[-1] in quotes:
        value = value[1:-1].strip()
    for ch in ('\ufeff', '\u200b', '\u200c', '\u200d', '\xa0'):
        value = value.replace(ch, '')
    return value.strip()


def eko_settings() -> EkoSettings:
    env = _env('EKO_ENVIRONMENT', 'uat')
    is_prod = env.lower() in ('production', 'prod', 'live')

    # UAT host is the same for every Eko partner. The production host is
    # specific to your organisation's onboarding (e.g. a white-labelled path
    # like "/ekoicici") and is issued after KYC is approved on
    # https://connect.eko.in. Do not use Eko's retired :25002 gateway port.
    base_default = '' if is_prod else 'https://staging.eko.in/ekoapi'

    initiator_id = _env('EKO_INITIATOR_ID')
    base_url = _env('EKO_BASE_URL', base_default).rstrip('/')
    # Retired payment gateway port — KYC/DigiLocker live on the host without :25002.
    if ':25002' in base_url:
        base_url = base_url.replace(':25002', '', 1)
    # Production host with a leftover UAT flag still needs the production key pair.
    if 'api.eko.in' in base_url and 'staging' not in base_url:
        if env.lower() not in ('production', 'prod', 'live'):
            env = 'production'
    # Penniless routes use an explicit partner slug from Eko — never infer it
    # from the white-label base URL (ekoicici != icici slug for KYC tools).
    org_slug = _env('EKO_ORG_SLUG')
    penniless_path = _env('EKO_PENNYLESS_PATH')
    if not penniless_path and org_slug:
        penniless_path = f'/v3/tools/kyc/{org_slug}/bank-acc-verify-penniless'

    return EkoSettings(
        developer_key=_env('EKO_DEVELOPER_KEY'),
        access_key=_env('EKO_ACCESS_KEY'),
        initiator_id=initiator_id,
        # Many single-retailer Eko partner setups use the same code for
        # initiator_id and user_code — fall back to initiator_id if unset.
        user_code=_env('EKO_USER_CODE') or initiator_id,
        environment=env,
        base_url=base_url,
        org_slug=org_slug,
        penniless_enabled=bool(getattr(settings, 'EKO_PENNYLESS_ENABLED', True)),
        penniless_path=penniless_path,
    )
