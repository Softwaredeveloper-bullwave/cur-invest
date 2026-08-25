"""Crypto app tests — preferences, watchlist, paper trading, auth gates."""

from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from crypto.models import CryptoAsset, CryptoWatchlistItem, UserMarketPreference
from crypto.paper_trading_service import place_paper_order, portfolio_summary
from crypto.providers.base import CryptoProviderError
from crypto.trading_provider import CryptoTradingDisabled, get_trading_provider

User = get_user_model()


class MarketPreferenceApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9111111111', name='Crypto Tester')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_get_creates_default_preference(self):
        resp = self.client.get('/api/v1/crypto/market-preference/')
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.data['has_completed_selection'])
        self.assertTrue(UserMarketPreference.objects.filter(user=self.user).exists())

    def test_put_requires_at_least_one_market(self):
        resp = self.client.put(
            '/api/v1/crypto/market-preference/',
            {'indian_market_enabled': False, 'crypto_market_enabled': False},
            format='json',
        )
        self.assertEqual(resp.status_code, 400)

    def test_put_saves_both_markets(self):
        # Exclusive: requesting both with active=crypto keeps crypto only
        resp = self.client.put(
            '/api/v1/crypto/market-preference/',
            {
                'indian_market_enabled': True,
                'crypto_market_enabled': True,
                'active_market': 'crypto',
            },
            format='json',
        )
        self.assertEqual(resp.status_code, 200)
        self.assertTrue(resp.data['has_completed_selection'])
        self.assertTrue(resp.data['crypto_market_enabled'])
        self.assertFalse(resp.data['indian_market_enabled'])
        self.assertEqual(resp.data['active_market'], 'crypto')

    def test_unauthenticated_rejected(self):
        anon = APIClient()
        resp = anon.get('/api/v1/crypto/market-preference/')
        self.assertIn(resp.status_code, (401, 403))


class CryptoWatchlistApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9222222222', name='Watchlist User')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.asset = CryptoAsset.objects.create(
            id='bitcoin', symbol='btc', name='Bitcoin', image_url=''
        )

    def test_add_and_list_and_delete_watchlist(self):
        resp = self.client.post(
            '/api/v1/crypto/watchlist/', {'asset_id': 'bitcoin'}, format='json'
        )
        self.assertIn(resp.status_code, (200, 201))
        item_id = resp.data['id']
        listed = self.client.get('/api/v1/crypto/watchlist/')
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.data['results']), 1)
        deleted = self.client.delete(f'/api/v1/crypto/watchlist/{item_id}/')
        self.assertEqual(deleted.status_code, 204)
        self.assertEqual(CryptoWatchlistItem.objects.filter(user=self.user).count(), 0)


class CryptoPaperTradingTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9333333333', name='Paper User')
        CryptoAsset.objects.create(id='ethereum', symbol='eth', name='Ethereum')

    @patch('crypto.paper_trading_service._inr_price', return_value=Decimal('200000.00'))
    def test_buy_and_portfolio(self, _mock_price):
        result = place_paper_order(
            self.user, asset_id='ethereum', side='BUY', quantity=Decimal('0.1')
        )
        self.assertTrue(result['is_paper'])
        self.assertEqual(result['environment'], 'PAPER TRADING')
        pf = portfolio_summary(self.user)
        self.assertEqual(len(pf['holdings']), 1)
        self.assertEqual(pf['holdings'][0]['symbol'], 'ETH')


class CryptoTradingProviderTests(TestCase):
    def test_live_trading_disabled_by_default(self):
        provider = get_trading_provider()
        with self.assertRaises(CryptoTradingDisabled):
            provider.create_order(symbol='BTC', side='BUY', quantity=1)


class CryptoOverviewFallbackTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9444444444', name='Overview User')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    @patch(
        'crypto.views.CryptoService.get_market_overview',
        side_effect=CryptoProviderError('down', retryable=True),
    )
    def test_overview_returns_503_on_provider_failure(self, _mock):
        resp = self.client.get('/api/v1/crypto/overview/')
        self.assertEqual(resp.status_code, 503)
        self.assertIn('detail', resp.data)


@override_settings(CRYPTO_TRADING_ENABLED=False)
class CryptoTradingStatusApiTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9555555555', name='Status User')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_trading_status_reports_paper_mode(self):
        resp = self.client.get('/api/v1/crypto/trading-status/')
        self.assertEqual(resp.status_code, 200)
        self.assertFalse(resp.data['enabled'])
        self.assertEqual(resp.data['mode'], 'paper_and_market_data')
