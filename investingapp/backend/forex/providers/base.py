"""Abstract forex market-data provider — swap implementations without touching Flutter."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class ForexProviderError(Exception):
    def __init__(self, message: str, *, retryable: bool = True, status_code: int | None = None):
        super().__init__(message)
        self.retryable = retryable
        self.status_code = status_code


class BaseForexProvider(ABC):
    name: str = 'base'

    @abstractmethod
    def get_market_overview(self) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_pairs(self, *, ids: list[str] | None = None) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_pair(self, pair_id: str) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_price(self, pair_id: str) -> dict[str, Any]:
        ...

    @abstractmethod
    def get_ohlcv(self, pair_id: str, *, period: str = '1D') -> dict[str, Any]:
        ...

    @abstractmethod
    def get_trending(self) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_top_gainers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def get_top_losers(self, *, limit: int = 20) -> list[dict[str, Any]]:
        ...

    @abstractmethod
    def search(self, query: str) -> list[dict[str, Any]]:
        ...
