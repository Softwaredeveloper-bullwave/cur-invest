from django.test import SimpleTestCase

from services.eko_auth import (
    build_eko_auth_headers,
    redact_eko_headers,
    sanitize_eko_payload,
)


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
