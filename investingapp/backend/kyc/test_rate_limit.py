from django.core.cache import cache
from django.test import SimpleTestCase, override_settings

from .rate_limit import RateLimitExceeded, check_rate_limit, clear_rate_limit


class RateLimitTests(SimpleTestCase):
    def setUp(self):
        cache.clear()

    @override_settings(KYC_RELAX_RATE_LIMITS=True, DEBUG=True)
    def test_relaxed_dev_limits_allow_more_attempts(self):
        for _ in range(10):
            check_rate_limit('kyc:bank:test-user', limit=5, window_seconds=300)
        check_rate_limit('kyc:bank:test-user', limit=5, window_seconds=300)

    @override_settings(KYC_RELAX_RATE_LIMITS=False, DEBUG=False)
    def test_production_limits_block_after_cap(self):
        for _ in range(5):
            check_rate_limit('kyc:bank:test-user', limit=5, window_seconds=300)
        with self.assertRaises(RateLimitExceeded) as ctx:
            check_rate_limit('kyc:bank:test-user', limit=5, window_seconds=300)
        self.assertIn('seconds', str(ctx.exception).lower())

    def test_clear_rate_limit_resets_bucket(self):
        for _ in range(3):
            check_rate_limit('kyc:bank:reset-user', limit=3, window_seconds=300)
        clear_rate_limit('kyc:bank:reset-user')
        check_rate_limit('kyc:bank:reset-user', limit=3, window_seconds=300)
