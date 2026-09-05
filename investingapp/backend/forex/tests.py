from unittest.mock import MagicMock, patch

from django.contrib.auth import get_user_model
from django.test import SimpleTestCase, override_settings
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

    @patch('forex.option_chain._spot', return_value=(1.16, 'test'))
    def test_eurusd_option_chain(self, _spot):
        resp = self.client.get('/api/v1/forex/pairs/eurusd/options/')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.data['assetClass'], 'forex')
        self.assertTrue(resp.data['contracts'])
        self.assertEqual(resp.data['contracts'][0]['underlyingId'], 'eurusd')

    def test_unknown_pair_options_404(self):
        resp = self.client.get('/api/v1/forex/pairs/usdchf/options/')
        self.assertEqual(resp.status_code, 404)


class ForexMarketauxNewsTests(SimpleTestCase):
    @override_settings(
        FOREX_NEWS_PROVIDER='marketaux',
        FOREX_NEWS_API_KEY='test-token',
        MARKETAUX_API_TOKEN='test-token',
        FOREX_NEWS_API_BASE_URL='https://api.marketaux.com/v1',
    )
    @patch('forex.news_service.record_provider_call')
    @patch('forex.news_service.cache')
    @patch('forex.news_service._fetch_rss', return_value=[])
    @patch('forex.news_service._persist_article')
    @patch('forex.news_service.httpx.Client')
    def test_marketaux_maps_currency_news(
        self, client_cls, _persist, _rss, cache_mock, _health
    ):
        from forex.news_service import fetch_forex_news

        cache_mock.get.return_value = None
        response = MagicMock()
        response.status_code = 200
        response.content = b'{}'
        response.json.return_value = {
            'data': [
                {
                    'uuid': 'abc123forexnews0000000000000001',
                    'title': 'Euro jumps after ECB comments',
                    'snippet': 'EURUSD rallied as traders priced in policy.',
                    'url': 'https://example.com/eurusd-ecb',
                    'image_url': 'https://example.com/chart.png',
                    'source': 'FXWire',
                    'published_at': '2026-09-05T04:00:00.000000Z',
                    'entities': [
                        {'symbol': 'EURUSD', 'type': 'currency'},
                        {'symbol': 'AAPL', 'type': 'equity'},
                    ],
                }
            ]
        }
        client_cls.return_value.__enter__.return_value.get.return_value = response

        articles = fetch_forex_news()
        self.assertEqual(len(articles), 1)
        self.assertEqual(articles[0]['title'], 'Euro jumps after ECB comments')
        self.assertEqual(articles[0]['related_pairs'], ['eurusd'])
        self.assertEqual(articles[0]['source'], 'FXWire')
        request_kwargs = client_cls.return_value.__enter__.return_value.get.call_args.kwargs
        self.assertEqual(request_kwargs['params']['entity_types'], 'currency')
        self.assertIn('forex', request_kwargs['params']['search'].lower())

    def test_usd_chip_matches_dollar_headline(self):
        from forex.news_service import _article_matches_category

        article = {
            'title': 'US dollar strengthens against the yen',
            'summary': 'Traders bought USD after data.',
            'category': 'Market Analysis',
            'related_pairs': ['usdjpy'],
        }
        self.assertTrue(_article_matches_category(article, 'usd'))
        self.assertFalse(_article_matches_category(article, 'inr'))
