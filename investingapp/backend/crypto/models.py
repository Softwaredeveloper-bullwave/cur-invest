"""Crypto market models — additive alongside Indian equities; paper-trading only for execution."""

from __future__ import annotations

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class UserMarketPreference(models.Model):
    """Markets the user opted into after KYC (Indian and/or crypto)."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='market_preference',
    )
    indian_market_enabled = models.BooleanField(default=True)
    crypto_market_enabled = models.BooleanField(default=False)
    # Active shell market when both are enabled: indian | crypto
    active_market = models.CharField(max_length=16, default='indian')
    has_completed_selection = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['has_completed_selection']),
        ]

    def __str__(self):
        return f'{self.user_id}: indian={self.indian_market_enabled} crypto={self.crypto_market_enabled}'


class CryptoAsset(models.Model):
    """Canonical crypto asset keyed by provider id (e.g. bitcoin), not free-form symbols."""

    id = models.CharField(primary_key=True, max_length=64)  # coingecko id
    symbol = models.CharField(max_length=32, db_index=True)
    name = models.CharField(max_length=120)
    image_url = models.URLField(max_length=500, blank=True, default='')
    market_cap_rank = models.PositiveIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    about = models.TextField(blank=True, default='')
    homepage_url = models.URLField(max_length=500, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['market_cap_rank', 'symbol']
        indexes = [
            models.Index(fields=['symbol', 'is_active']),
        ]

    def __str__(self):
        return f'{self.symbol.upper()} ({self.name})'


class CryptoMarketSnapshot(models.Model):
    """Cached last-known market stats for an asset (Decimal money fields)."""

    asset = models.OneToOneField(
        CryptoAsset, on_delete=models.CASCADE, related_name='snapshot'
    )
    current_price = models.DecimalField(max_digits=24, decimal_places=8, default=Decimal('0'))
    price_change_24h = models.DecimalField(max_digits=24, decimal_places=8, default=Decimal('0'))
    price_change_percentage_24h = models.DecimalField(
        max_digits=12, decimal_places=4, default=Decimal('0')
    )
    high_24h = models.DecimalField(max_digits=24, decimal_places=8, null=True, blank=True)
    low_24h = models.DecimalField(max_digits=24, decimal_places=8, null=True, blank=True)
    market_cap = models.DecimalField(max_digits=28, decimal_places=2, null=True, blank=True)
    fully_diluted_valuation = models.DecimalField(
        max_digits=28, decimal_places=2, null=True, blank=True
    )
    total_volume = models.DecimalField(max_digits=28, decimal_places=2, null=True, blank=True)
    circulating_supply = models.DecimalField(max_digits=28, decimal_places=4, null=True, blank=True)
    total_supply = models.DecimalField(max_digits=28, decimal_places=4, null=True, blank=True)
    max_supply = models.DecimalField(max_digits=28, decimal_places=4, null=True, blank=True)
    ath = models.DecimalField(max_digits=24, decimal_places=8, null=True, blank=True)
    atl = models.DecimalField(max_digits=24, decimal_places=8, null=True, blank=True)
    currency = models.CharField(max_length=8, default='usd')
    sparkline_7d = models.JSONField(default=list, blank=True)
    provider = models.CharField(max_length=40, blank=True, default='')
    fetched_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.asset_id} @ {self.current_price}'


class CryptoWatchlistItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_watchlist_items',
    )
    asset = models.ForeignKey(CryptoAsset, on_delete=models.CASCADE, related_name='watchers')
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'asset')
        ordering = ['-added_at']


class CryptoPracticeWallet(models.Model):
    """Virtual INR cash for crypto paper trading — separate from equities PracticeWallet."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_practice_wallet',
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('100000'))
    currency = models.CharField(max_length=8, default='INR')
    last_refilled_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)


class CryptoHolding(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_holdings',
    )
    asset = models.ForeignKey(CryptoAsset, on_delete=models.CASCADE, related_name='holdings')
    quantity = models.DecimalField(max_digits=28, decimal_places=12, default=Decimal('0'))
    avg_price = models.DecimalField(max_digits=24, decimal_places=8, default=Decimal('0'))
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'asset')


class CryptoTransaction(models.Model):
    class TxType(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'
        DEPOSIT = 'DEPOSIT', 'Deposit'
        WITHDRAWAL = 'WITHDRAWAL', 'Withdrawal'
        TRANSFER = 'TRANSFER', 'Transfer'

    class Status(models.TextChoices):
        PENDING = 'Pending', 'Pending'
        COMPLETED = 'Completed', 'Completed'
        FAILED = 'Failed', 'Failed'
        CANCELLED = 'Cancelled', 'Cancelled'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_transactions',
    )
    asset = models.ForeignKey(
        CryptoAsset, on_delete=models.PROTECT, related_name='transactions', null=True, blank=True
    )
    tx_type = models.CharField(max_length=16, choices=TxType.choices)
    quantity = models.DecimalField(max_digits=28, decimal_places=12, default=Decimal('0'))
    price = models.DecimalField(max_digits=24, decimal_places=8, default=Decimal('0'))
    total_value = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal('0'))
    fees = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    currency = models.CharField(max_length=8, default='INR')
    exchange = models.CharField(max_length=64, blank=True, default='PAPER')
    external_id = models.CharField(max_length=120, blank=True, default='')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.COMPLETED)
    is_paper = models.BooleanField(default=True)
    notes = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['tx_type', 'status']),
        ]


class CryptoNewsArticle(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    title = models.CharField(max_length=400)
    summary = models.TextField(blank=True, default='')
    image_url = models.URLField(max_length=500, blank=True, default='')
    source = models.CharField(max_length=120)
    published_at = models.DateTimeField(db_index=True)
    category = models.CharField(max_length=40, default='Market Analysis', db_index=True)
    related_assets = models.JSONField(default=list, blank=True)
    external_url = models.URLField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-published_at']


class CryptoPriceAlert(models.Model):
    class Condition(models.TextChoices):
        ABOVE = 'above', 'Above'
        BELOW = 'below', 'Below'
        PCT_UP = 'pct_up', 'Percent up'
        PCT_DOWN = 'pct_down', 'Percent down'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_price_alerts',
    )
    asset = models.ForeignKey(CryptoAsset, on_delete=models.CASCADE, related_name='alerts')
    condition = models.CharField(max_length=16, choices=Condition.choices)
    target_value = models.DecimalField(max_digits=24, decimal_places=8)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)


class CryptoNotificationPreference(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='crypto_notification_preference',
    )
    price_alerts = models.BooleanField(default=True)
    news_alerts = models.BooleanField(default=True)
    volatility_alerts = models.BooleanField(default=False)
    percent_move_threshold = models.DecimalField(
        max_digits=6, decimal_places=2, default=Decimal('5.00')
    )
    updated_at = models.DateTimeField(auto_now=True)


class CryptoProviderHealth(models.Model):
    """Internal monitoring for external crypto services."""

    class Status(models.TextChoices):
        HEALTHY = 'HEALTHY', 'Healthy'
        DEGRADED = 'DEGRADED', 'Degraded'
        DOWN = 'DOWN', 'Down'
        UNKNOWN = 'UNKNOWN', 'Unknown'

    service = models.CharField(max_length=40, unique=True)  # market_data | news | ai
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.UNKNOWN)
    provider_name = models.CharField(max_length=64, blank=True, default='')
    last_success_at = models.DateTimeField(null=True, blank=True)
    last_error_at = models.DateTimeField(null=True, blank=True)
    last_error_message = models.CharField(max_length=500, blank=True, default='')
    avg_response_ms = models.PositiveIntegerField(null=True, blank=True)
    rate_limit_hits = models.PositiveIntegerField(default=0)
    error_count = models.PositiveIntegerField(default=0)
    success_count = models.PositiveIntegerField(default=0)
    data_freshness_seconds = models.PositiveIntegerField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.service}: {self.status}'


class CryptoApiRequestLog(models.Model):
    """Non-sensitive audit of provider calls (no API keys)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    service = models.CharField(max_length=40, db_index=True)
    endpoint = models.CharField(max_length=200)
    success = models.BooleanField(default=True)
    status_code = models.PositiveIntegerField(null=True, blank=True)
    response_ms = models.PositiveIntegerField(null=True, blank=True)
    error_type = models.CharField(max_length=64, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-created_at']
