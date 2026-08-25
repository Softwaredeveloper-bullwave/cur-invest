"""Crypto news via legitimate RSS feeds — cached; never scrapes paywalled content."""

from __future__ import annotations

import hashlib
import logging
import re
from datetime import datetime, timezone as dt_timezone
from email.utils import parsedate_to_datetime
from zoneinfo import ZoneInfo

import feedparser
import httpx
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone

from .health import record_provider_call
from .models import CryptoNewsArticle

logger = logging.getLogger('bullwave.crypto')
IST = ZoneInfo('Asia/Kolkata')

CRYPTO_FEEDS = (
    ('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/'),
    ('CoinTelegraph', 'https://cointelegraph.com/rss'),
    ('Bitcoin Magazine', 'https://bitcoinmagazine.com/.rss/full/'),
)

CATEGORIES = (
    'Bitcoin',
    'Ethereum',
    'Altcoins',
    'DeFi',
    'Web3',
    'Regulation',
    'Blockchain',
    'Exchange News',
    'Market Analysis',
)

RSS_HEADERS = {
    'User-Agent': 'CapitalBullWave/1.0 (crypto-news; +https://capitalbullwave.com)',
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
}


def _stable_id(url: str, title: str) -> str:
    raw = (url or title).encode('utf-8', errors='ignore')
    return hashlib.sha256(raw).hexdigest()[:32]


def _clean_html(text: str) -> str:
    if not text:
        return ''
    text = re.sub(r'<[^>]+>', ' ', text)
    return re.sub(r'\s+', ' ', text).strip()


def _parse_published(entry) -> datetime:
    if getattr(entry, 'published_parsed', None):
        try:
            dt = datetime(*entry.published_parsed[:6], tzinfo=IST)
            return dt.astimezone(dt_timezone.utc)
        except (TypeError, ValueError):
            pass
    published = getattr(entry, 'published', '') or getattr(entry, 'updated', '')
    if published:
        try:
            return parsedate_to_datetime(published)
        except (TypeError, ValueError):
            pass
    return timezone.now()


def _category_for(title: str, summary: str) -> str:
    text = f'{title} {summary}'.lower()
    rules = (
        ('Bitcoin', ('bitcoin', 'btc')),
        ('Ethereum', ('ethereum', 'eth', 'vitalik')),
        ('DeFi', ('defi', 'uniswap', 'aave', 'yield')),
        ('Web3', ('web3', 'nft', 'metaverse')),
        ('Regulation', ('sec', 'regulation', 'ban', 'lawsuit', 'compliance')),
        ('Exchange News', ('binance', 'coinbase', 'exchange', 'kraken')),
        ('Blockchain', ('blockchain', 'layer-2', 'rollup')),
        ('Altcoins', ('solana', 'xrp', 'cardano', 'dogecoin', 'altcoin')),
    )
    for cat, keys in rules:
        if any(k in text for k in keys):
            return cat
    return 'Market Analysis'


def _related_assets(title: str, summary: str) -> list[str]:
    text = f'{title} {summary}'.lower()
    mapping = {
        'bitcoin': 'bitcoin',
        'btc': 'bitcoin',
        'ethereum': 'ethereum',
        'eth': 'ethereum',
        'solana': 'solana',
        'xrp': 'ripple',
        'cardano': 'cardano',
        'dogecoin': 'dogecoin',
        'bnb': 'binancecoin',
    }
    found = []
    for key, aid in mapping.items():
        if key in text and aid not in found:
            found.append(aid)
    return found[:5]


def _entry_image(entry) -> str:
    media = getattr(entry, 'media_content', None) or getattr(entry, 'media_thumbnail', None)
    if isinstance(media, list) and media:
        url = media[0].get('url') if isinstance(media[0], dict) else ''
        if url:
            return url
    summary = getattr(entry, 'summary', '') or ''
    m = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', summary, re.I)
    return m.group(1) if m else ''


def fetch_crypto_news(*, category: str | None = None, force: bool = False) -> list[dict]:
    cache_minutes = int(getattr(settings, 'CRYPTO_NEWS_CACHE_MINUTES', 15) or 15)
    cache_key = f'crypto:news:{category or "all"}'
    if not force:
        cached = cache.get(cache_key)
        if cached is not None:
            return cached

    articles: list[dict] = []
    started = timezone.now()
    try:
        for source, url in CRYPTO_FEEDS:
            try:
                with httpx.Client(timeout=15) as client:
                    resp = client.get(url, headers=RSS_HEADERS)
                if resp.status_code != 200:
                    continue
                feed = feedparser.parse(resp.text)
            except Exception:
                logger.debug('Crypto news feed failed: %s', source, exc_info=True)
                continue

            for entry in feed.entries[:25]:
                title = _clean_html(getattr(entry, 'title', '') or '')
                if not title:
                    continue
                link = getattr(entry, 'link', '') or ''
                summary = _clean_html(
                    getattr(entry, 'summary', '') or getattr(entry, 'description', '') or ''
                )[:600]
                cat = _category_for(title, summary)
                if category and category.lower() not in {cat.lower(), 'all'}:
                    if category.lower() != cat.lower():
                        continue
                aid = _stable_id(link, title)
                published = _parse_published(entry)
                row = {
                    'id': aid,
                    'title': title[:400],
                    'summary': summary,
                    'image_url': _entry_image(entry)[:500],
                    'source': source,
                    'published_at': published.isoformat(),
                    'category': cat,
                    'related_cryptocurrencies': _related_assets(title, summary),
                    'external_url': link[:500],
                }
                articles.append(row)
                CryptoNewsArticle.objects.update_or_create(
                    id=aid,
                    defaults={
                        'title': row['title'],
                        'summary': summary,
                        'image_url': row['image_url'],
                        'source': source,
                        'published_at': published,
                        'category': cat,
                        'related_assets': row['related_cryptocurrencies'],
                        'external_url': row['external_url'],
                    },
                )

        articles.sort(key=lambda a: a['published_at'], reverse=True)
        articles = articles[:80]
        elapsed = int((timezone.now() - started).total_seconds() * 1000)
        record_provider_call(
            service='news',
            endpoint='rss',
            success=True,
            response_ms=elapsed,
            provider_name=getattr(settings, 'CRYPTO_NEWS_PROVIDER', 'rss') or 'rss',
        )
        cache.set(cache_key, articles, cache_minutes * 60)
        return articles
    except Exception as exc:
        record_provider_call(
            service='news',
            endpoint='rss',
            success=False,
            error_type=type(exc).__name__,
            error_message=str(exc)[:400],
            provider_name='rss',
        )
        cached = cache.get(cache_key)
        if cached:
            return cached
        # DB fallback
        qs = CryptoNewsArticle.objects.all()[:50]
        return [
            {
                'id': a.id,
                'title': a.title,
                'summary': a.summary,
                'image_url': a.image_url,
                'source': a.source,
                'published_at': a.published_at.isoformat(),
                'category': a.category,
                'related_cryptocurrencies': a.related_assets,
                'external_url': a.external_url,
                'stale': True,
            }
            for a in qs
        ]
