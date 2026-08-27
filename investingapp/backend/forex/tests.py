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
