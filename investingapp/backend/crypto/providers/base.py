"""Abstract crypto market-data provider — swap implementations without touching Flutter."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class CryptoProviderError(Exception):
    """Raised when an external crypto provider fails."""

    def __init__(self, message: str, *, retryable: bool = True, status_code: int | None = None):
        super().__init__(message)
        self.retryable = retryable
        self.status_code = status_code


class BaseCryptoProvider(ABC):
    name: str = 'base'

    @abstractmethod
    def get_market_overview(self) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_assets(
        self,
        *,
        page: int = 1,
        page_size: int = 50,
        vs_currency: str = 'usd',
        order: str = 'market_cap_desc',
        ids: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_asset(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        ...

    @abstractmethod
    def get_price(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        ...

    @abstractmethod
    def get_ohlcv(
        self,
        asset_id: str,
        *,
        vs_currency: str = 'usd',
        days: str = '1',
    ) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_market_stats(self, asset_id: str, *, vs_currency: str = 'usd') -> dict[str, Any]:
        ...

    @abstractmethod
    def get_trending(self) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_top_gainers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_top_losers(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_volume_data(self, *, limit: int = 20, vs_currency: str = 'usd') -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def search(self, query: str) -> list[dict[str, Any]]:
        ...

    def get_fear_greed(self) -> dict[str, Any] | None:
        return None
