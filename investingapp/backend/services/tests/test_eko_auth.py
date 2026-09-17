import base64
import hashlib
import hmac

from types import SimpleNamespace

from django.test import SimpleTestCase, override_settings

from services.eko_auth import (
    build_eko_auth_headers,
    redact_eko_headers,
    sanitize_eko_payload,
)
from services.providers.eko_config import eko_settings
from services.providers.eko_kyc import EkoKycError, _ensure_eko_credentials


class EkoAuthTests(SimpleTestCase):
    def test_build_auth_headers_uses_hmac_and_timestamp(self):
        headers = build_eko_auth_headers(
            developer_key='dev-key',
            access_key='access-key',
            timestamp_ms=1700000000000,
        )

        self.assertEqual(headers['developer_key'], 'dev-key')
        self.assertEqual(headers['secret-key-timestamp'], '1700000000000')
        self.assertTrue(headers['secret-key'])
        self.assertEqual(headers['accept'], 'application/json')
        encoded_key = base64.b64encode(b'access-key').decode()
        expected = base64.b64encode(
            hmac.new(encoded_key.encode(), b'1700000000000', hashlib.sha256).digest()
        ).decode()
        self.assertEqual(headers['secret-key'], expected)

    def test_raw_hmac_mode_differs_from_official_b64_string(self):
        kwargs = dict(developer_key='dev-key', access_key='access-key', timestamp_ms=1700000000000)
        official = build_eko_auth_headers(**kwargs, hmac_key_mode='b64_string')
        raw = build_eko_auth_headers(**kwargs, hmac_key_mode='raw')
        self.assertNotEqual(official['secret-key'], raw['secret-key'])

    def test_redact_eko_headers_hides_secrets(self):
        redacted = redact_eko_headers(
            {
                'developer_key': 'dev',
                'secret-key': 'sekret',
                'content-type': 'application/json',
            }
        )

        self.assertEqual(redacted['developer_key'], '***')
        self.assertEqual(redacted['secret-key'], '***')
        self.assertEqual(redacted['content-type'], 'application/json')

    def test_sanitize_eko_payload_masks_account(self):
        cleaned = sanitize_eko_payload(
            {'account': '1234567890', 'ifsc': 'HDFC0001234'},
            mask_account=lambda value: f'****{value[-4:]}',
        )

        self.assertEqual(cleaned['account'], '****7890')
        self.assertEqual(cleaned['ifsc'], 'HDFC0001234')


class EkoConfigTests(SimpleTestCase):
    @override_settings(
        EKO_ENVIRONMENT='production',
        EKO_BASE_URL='https://api.eko.in:25002/ekoicici',
        EKO_DEVELOPER_KEY='dev',
        EKO_ACCESS_KEY='access',
        EKO_INITIATOR_ID='9616212526',
        EKO_USER_CODE='23880001',
        EKO_ORG_SLUG='',
        EKO_PENNYLESS_PATH='',
        EKO_PENNYLESS_ENABLED=True,
    )
    def test_strips_retired_gateway_port_from_base_url(self):
        cfg = eko_settings()
        self.assertEqual(cfg.base_url, 'https://api.eko.in/ekoicici')

    @override_settings(
        EKO_ENVIRONMENT='uat',
        EKO_BASE_URL='https://api.eko.in/ekoicici',
        EKO_DEVELOPER_KEY='dev',
        EKO_ACCESS_KEY='access',
        EKO_INITIATOR_ID='9616212526',
        EKO_USER_CODE='23880001',
        EKO_ORG_SLUG='',
        EKO_PENNYLESS_PATH='',
        EKO_PENNYLESS_ENABLED=True,
    )
    def test_production_host_promotes_uat_environment(self):
        cfg = eko_settings()
        self.assertTrue(cfg.is_production)
        self.assertEqual(cfg.environment, 'production')

    @override_settings(
        EKO_ENVIRONMENT='production',
        EKO_BASE_URL='https://api.eko.in/ekoicici',
        EKO_DEVELOPER_KEY='"dev-key"',
        EKO_ACCESS_KEY="'access-key'",
        EKO_INITIATOR_ID='9616212526',
        EKO_USER_CODE='23880001',
        EKO_ORG_SLUG='',
        EKO_PENNYLESS_PATH='',
        EKO_PENNYLESS_ENABLED=True,
    )
    def test_strips_quoted_eko_keys(self):
        cfg = eko_settings()
        self.assertEqual(cfg.developer_key, 'dev-key')
        self.assertEqual(cfg.access_key, 'access-key')


class EkoCredentialGuardTests(SimpleTestCase):
    def test_truncated_uuid_access_key_is_rejected(self):
        cfg = SimpleNamespace(
            is_configured=True,
            access_key='69095f1a-1234-1234-1234-12345678901',
            developer_key='a' * 32,
        )
        self.assertEqual(len(cfg.access_key), 35)
        with self.assertRaises(EkoKycError) as ctx:
            _ensure_eko_credentials(cfg)
        self.assertEqual(ctx.exception.code, 'auth_failed')
        self.assertIn('truncated', str(ctx.exception).lower())
