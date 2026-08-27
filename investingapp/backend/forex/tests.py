from unittest.mock import patch

from django.contrib.auth import get_user_model
from rest_framework.test import APITestCase

from forex.pairs import FOREX_PAIRS

User = get_user_model()


class ForexApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9990000111', password='x')
        self.client.force_authenticate(self.user)

    def test_overview_uses_provider(self):
        fake = {
            'total_pairs': 2,
            'majors': [],
            'trending': [
                {
                    'id': 'eurusd',
                    'symbol': 'EUR/USD',
                    'name': 'Euro / US Dollar',
                    'category': 'Majors',
                    'current_price': '1.08',
                    'price_change_percentage_24h': '0.12',
                    'sparkline_7d': [1.07, 1.08],
                }
            ],
            'top_gainers': [],
            'top_losers': [],
            'provider': 'test',
        }
        with patch('forex.views.ForexService.get_market_overview', return_value=fake):
            resp = self.client.get('/api/v1/forex/overview/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['provider'], 'test')

    def test_trading_disabled(self):
        resp = self.client.get('/api/v1/forex/trading-status/')
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.data['enabled'])

    def test_pair_catalog_includes_usd_inr(self):
        ids = {row[0] for row in FOREX_PAIRS}
        self.assertIn('eurusd', ids)
        self.assertIn('usdinr', ids)

    def test_overview_hides_vendor_apikey_error(self):
        from forex.providers.base import ForexProviderError

        err = ForexProviderError(
            'apikey parameter is incorrect or not specified. '
            'You can get your free API key instantly following this link: https://twelvedata.com/pricing'
        )
        with patch('forex.views.ForexService.get_market_overview', side_effect=err):
            resp = self.client.get('/api/v1/forex/overview/')
        self.assertEqual(resp.status_code, 503)
        detail = str(resp.data.get('detail') or '').lower()
        self.assertNotIn('apikey', detail)
        self.assertNotIn('twelvedata', detail)
        self.assertNotIn('http', detail)

    def test_pairs_failover_when_twelve_data_rejects_key(self):
        from decimal import Decimal
        from unittest.mock import MagicMock

        from forex.providers.base import ForexProviderError
        from forex.services import ForexService

        twelve = MagicMock()
        twelve.name = 'twelvedata'
        twelve.get_pairs.side_effect = ForexProviderError('Twelve Data key was rejected.')
        frank = MagicMock()
        frank.name = 'frankfurter'
        frank.get_pairs.return_value = [
            {
                'id': 'eurusd',
                'symbol': 'EUR/USD',
                'name': 'Euro / US Dollar',
                'category': 'Majors',
                'current_price': Decimal('1.08'),
                'price_change_24h': Decimal('0'),
                'price_change_percentage_24h': Decimal('0.12'),
                'base_currency': 'EUR',
                'quote_currency': 'USD',
                'sparkline_7d': [1.07, 1.08],
            }
        ]
        svc = ForexService(chain=[twelve, frank])
        with patch.object(svc, '_upsert_pairs'):
            rows = svc.get_pairs()
        self.assertEqual(rows[0]['id'], 'eurusd')
        twelve.get_pairs.assert_called()
        frank.get_pairs.assert_called()
