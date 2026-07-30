from decimal import Decimal
from unittest.mock import patch

from django.test import TestCase

from accounts.models import User

from .models import ScalperOrder, Stock
from .scalper_service import create_scalper_order, process_scalper_orders


class ScalperOrderTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone='9333333333', name='Scalper User')
        self.stock = Stock.objects.create(
            symbol='TEST',
            name='Test Limited',
            sector='Technology',
            ltp=Decimal('100'),
            open_price=Decimal('99'),
            high=Decimal('102'),
            low=Decimal('98'),
            previous_close=Decimal('99'),
        )

    @patch('stocks.scalper_service._execute')
    @patch('stocks.scalper_service.current_scalper_price')
    def test_market_entry_becomes_active_with_risk_controls(self, price, execute):
        price.return_value = Decimal('100')
        execute.return_value = {'id': 'trade-1', 'price': 100}
        order = create_scalper_order(
            self.user,
            instrument_type='stock',
            order_type='market',
            side='BUY',
            quantity=2,
            symbol='TEST',
            requested_price=100,
            stop_loss=98,
            target_price=105,
            trailing_stop_percent=1,
        )
        self.assertEqual(order.status, ScalperOrder.Status.ACTIVE)
        self.assertEqual(order.entry_trade_id, 'trade-1')
        self.assertEqual(order.stop_loss, Decimal('98'))

    @patch('stocks.scalper_service._execute')
    @patch('stocks.scalper_service.current_scalper_price')
    def test_limit_entry_executes_when_price_crosses(self, price, execute):
        price.return_value = Decimal('99')
        execute.return_value = {'id': 'trade-2', 'price': 99}
        order = create_scalper_order(
            self.user,
            instrument_type='stock',
            order_type='limit',
            side='BUY',
            quantity=1,
            symbol='TEST',
            requested_price=100,
            limit_price=99,
        )
        self.assertEqual(order.status, ScalperOrder.Status.PENDING)
        self.assertEqual(process_scalper_orders(), 1)
        order.refresh_from_db()
        self.assertEqual(order.status, ScalperOrder.Status.ACTIVE)

    @patch('stocks.scalper_service._execute')
    @patch('stocks.scalper_service.current_scalper_price')
    def test_stop_loss_closes_active_position(self, price, execute):
        price.side_effect = [Decimal('100'), Decimal('97')]
        execute.side_effect = [
            {'id': 'entry', 'price': 100},
            {'id': 'exit', 'price': 97},
        ]
        order = create_scalper_order(
            self.user,
            instrument_type='stock',
            order_type='market',
            side='BUY',
            quantity=1,
            symbol='TEST',
            requested_price=100,
            stop_loss=98,
        )
        self.assertEqual(process_scalper_orders(), 1)
        order.refresh_from_db()
        self.assertEqual(order.status, ScalperOrder.Status.EXECUTED)
        self.assertEqual(order.exit_reason, ScalperOrder.ExitReason.STOP_LOSS)
