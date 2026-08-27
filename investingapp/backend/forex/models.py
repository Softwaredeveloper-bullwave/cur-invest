"""Forex market models — additive alongside Indian equities and crypto."""

from __future__ import annotations

import uuid
from decimal import Decimal

from django.conf import settings
from django.db import models


class ForexPair(models.Model):
    """Canonical FX pair keyed by id (e.g. eurusd)."""

    id = models.CharField(primary_key=True, max_length=16)
    base_currency = models.CharField(max_length=8)
    quote_currency = models.CharField(max_length=8)
    symbol = models.CharField(max_length=16, db_index=True)
    name = models.CharField(max_length=120)
    category = models.CharField(max_length=32, default='Majors', db_index=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['category', 'symbol']

    def __str__(self):
        return self.symbol


class ForexMarketSnapshot(models.Model):
    pair = models.OneToOneField(ForexPair, on_delete=models.CASCADE, related_name='snapshot')
    current_price = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    price_change_24h = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    price_change_percentage_24h = models.DecimalField(
        max_digits=12, decimal_places=4, default=Decimal('0')
    )
    high_24h = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)
    low_24h = models.DecimalField(max_digits=18, decimal_places=6, null=True, blank=True)
    sparkline_7d = models.JSONField(default=list, blank=True)
    provider = models.CharField(max_length=40, blank=True, default='')
    fetched_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)


class ForexWatchlistItem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='forex_watchlist_items',
    )
    pair = models.ForeignKey(ForexPair, on_delete=models.CASCADE, related_name='watchers')
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'pair')
        ordering = ['-added_at']


class ForexPracticeWallet(models.Model):
    """Virtual INR cash for forex paper trading — separate from stocks/crypto wallets."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='forex_practice_wallet',
    )
    balance = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('100000'))
    currency = models.CharField(max_length=8, default='INR')
    last_refilled_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)


class ForexHolding(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='forex_holdings',
    )
    pair = models.ForeignKey(ForexPair, on_delete=models.CASCADE, related_name='holdings')
    quantity = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    avg_price = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'pair')


class ForexTransaction(models.Model):
    class TxType(models.TextChoices):
        BUY = 'BUY', 'Buy'
        SELL = 'SELL', 'Sell'

    class Status(models.TextChoices):
        PENDING = 'Pending', 'Pending'
        COMPLETED = 'Completed', 'Completed'
        FAILED = 'Failed', 'Failed'
        CANCELLED = 'Cancelled', 'Cancelled'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='forex_transactions',
    )
    pair = models.ForeignKey(
        ForexPair, on_delete=models.PROTECT, related_name='transactions', null=True, blank=True
    )
    tx_type = models.CharField(max_length=16, choices=TxType.choices)
    quantity = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    price = models.DecimalField(max_digits=18, decimal_places=6, default=Decimal('0'))
    total_value = models.DecimalField(max_digits=18, decimal_places=2, default=Decimal('0'))
    fees = models.DecimalField(max_digits=14, decimal_places=2, default=Decimal('0'))
    currency = models.CharField(max_length=8, default='INR')
    exchange = models.CharField(max_length=64, blank=True, default='PAPER')
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.COMPLETED)
    is_paper = models.BooleanField(default=True)
    notes = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']


class ForexNewsArticle(models.Model):
    id = models.CharField(primary_key=True, max_length=64)
    title = models.CharField(max_length=400)
    summary = models.TextField(blank=True, default='')
    image_url = models.CharField(max_length=1000, blank=True, default='')
    source = models.CharField(max_length=120)
    published_at = models.DateTimeField(db_index=True)
    category = models.CharField(max_length=40, default='Market Analysis', db_index=True)
    related_pairs = models.JSONField(default=list, blank=True)
    external_url = models.URLField(max_length=500)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-published_at']


class ForexNotificationPreference(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='forex_notification_preference',
    )
    price_alerts = models.BooleanField(default=True)
    news_alerts = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)


class ForexProviderHealth(models.Model):
    class Status(models.TextChoices):
        HEALTHY = 'HEALTHY', 'Healthy'
        DEGRADED = 'DEGRADED', 'Degraded'
        DOWN = 'DOWN', 'Down'
        UNKNOWN = 'UNKNOWN', 'Unknown'

    service = models.CharField(max_length=40, unique=True)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.UNKNOWN)
    provider_name = models.CharField(max_length=64, blank=True, default='')
    last_success_at = models.DateTimeField(null=True, blank=True)
    last_error_at = models.DateTimeField(null=True, blank=True)
    last_error_message = models.CharField(max_length=500, blank=True, default='')
    avg_response_ms = models.PositiveIntegerField(null=True, blank=True)
    rate_limit_hits = models.PositiveIntegerField(default=0)
    error_count = models.PositiveIntegerField(default=0)
    success_count = models.PositiveIntegerField(default=0)
    updated_at = models.DateTimeField(auto_now=True)


class ForexApiRequestLog(models.Model):
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
