from django.test import TestCase


class HealthViewTests(TestCase):
    def test_internal_health_returns_json(self):
        response = self.client.get('/health/', REMOTE_ADDR='127.0.0.1')

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertIn(payload['status'], ('ok', 'degraded'))
        self.assertIsInstance(payload['integrations']['database']['name'], str)
