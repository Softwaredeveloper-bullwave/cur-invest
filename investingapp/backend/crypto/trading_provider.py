"""Live crypto trading provider stub — NOT connected until compliance/exchange credentials exist."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class CryptoTradingDisabled(Exception):
    """Raised when real crypto trading is requested but not enabled."""


class BaseCryptoTradingProvider(ABC):
    name: str = 'base'

    @abstractmethod
    def get_account(self) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_balances(self) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def create_order(self, **kwargs) -> dict[str, Any]:
        ...

    @abstractmethod
    def cancel_order(self, order_id: str) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_order(self, order_id: str) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_orders(self) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_trades(self) -> list[dict[str, Any]]:
        ...


class DisabledCryptoTradingProvider(BaseCryptoTradingProvider):
    """Default — market data and paper trading only."""

    name = 'disabled'

    def _deny(self):
        raise CryptoTradingDisabled(
            'Real-money crypto trading is not enabled. '
            'Configure exchange credentials and compliance before activating CryptoTradingProvider.'
        )

    def get_account(self) -> dict[str, Any]:
        self._deny()

    def get_balances(self) -> list[dict[str, Any]]:
        self._deny()

    def create_order(self, **kwargs) -> dict[str, Any]:
        self._deny()

    def cancel_order(self, order_id: str) -> dict[str, Any]:
        self._deny()

    def get_order(self, order_id: str) -> dict[str, Any]:
        self._deny()

    def get_orders(self) -> list[dict[str, Any]]:
        self._deny()

    def get_trades(self) -> list[dict[str, Any]]:
        self._deny()


def get_trading_provider() -> BaseCryptoTradingProvider:
    from django.conf import settings

    enabled = bool(getattr(settings, 'CRYPTO_TRADING_ENABLED', False))
    if not enabled:
        return DisabledCryptoTradingProvider()
    # Future: return Binance/Coinbase providers when credentials + legal OK
    return DisabledCryptoTradingProvider()
