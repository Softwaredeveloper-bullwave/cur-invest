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
    ('CoinDesk', 'https://www.coindesk.com/arc/outboundfeeds/rss/?outputType=xml'),
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
        ('Bitcoin', r'\b(bitcoin|btc)\b'),
        ('Ethereum', r'\b(ethereum|\beth\b|vitalik)\b'),
        ('DeFi', r'\b(defi|uniswap|aave|yield farming)\b'),
        ('Web3', r'\b(web3|nft|metaverse)\b'),
        ('Regulation', r'\b(sec|regulation|lawsuit|compliance|cftc)\b'),
        ('Exchange News', r'\b(binance|coinbase|kraken|exchange)\b'),
        ('Blockchain', r'\b(blockchain|layer-2|rollup)\b'),
        ('Altcoins', r'\b(solana|\bsol\b|xrp|cardano|dogecoin|altcoin)\b'),
    )
    for cat, pattern in rules:
        if re.search(pattern, text, re.I):
            return cat
    return 'Market Analysis'


_BLOCKED_SOURCES = (
    'pypi.org',
    'npmjs.com',
    'crates.io',
    'github.com',
    'gitlab.com',
    'stackoverflow.com',
)

_CRYPTO_TERMS = (
    'bitcoin', 'btc', 'ethereum', 'eth', 'crypto', 'blockchain', 'web3',
    'defi', 'nft', 'solana', 'xrp', 'token', 'stablecoin', 'binance',
    'coinbase', 'altcoin', 'mining', 'wallet',
)

NEWSAPI_DOMAINS = (
    'coindesk.com,cointelegraph.com,decrypt.co,theblock.co,'
    'bitcoinmagazine.com,coinmarketcap.com,cryptoslate.com,blockworks.co'
)


def _is_crypto_article(title: str, summary: str, source: str, url: str) -> bool:
    blob = f'{source} {url} {title} {summary}'.lower()
    if any(blocked in blob for blocked in _BLOCKED_SOURCES):
        return False
    return any(term in blob for term in _CRYPTO_TERMS)


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


def _first_http_url(value) -> str:
    if isinstance(value, str):
        url = value.strip()
        if url.startswith('//'):
            url = f'https:{url}'
        if url.startswith(('http://', 'https://')):
            lower = url.lower()
            if any(skip in lower for skip in ('1x1', 'pixel.gif', 'spacer.', 'blank.gif')):
                return ''
            return url
        return ''
    if isinstance(value, dict):
        return _first_http_url(value.get('url') or value.get('href') or value.get('src') or '')
    if isinstance(value, (list, tuple)):
        for item in value:
            found = _first_http_url(item)
            if found:
                return found
    return ''


def _entry_image(entry) -> str:
    url = _first_http_url(getattr(entry, 'media_content', None))
    if url:
        return url
    url = _first_http_url(getattr(entry, 'media_thumbnail', None))
    if url:
        return url
    url = _first_http_url(getattr(entry, 'image', None))
    if url:
        return url
    url = _first_http_url(getattr(entry, 'enclosures', None))
    if url:
        return url
    for link in getattr(entry, 'links', None) or []:
        if not isinstance(link, dict):
            continue
        typ = (link.get('type') or '').lower()
        rel = (link.get('rel') or '').lower()
        if typ.startswith('image') or 'image' in rel or rel == 'enclosure':
            found = _first_http_url(link.get('href') or '')
            if found:
                return found
    html_parts = [
        getattr(entry, 'summary', '') or '',
        getattr(entry, 'description', '') or '',
    ]
    for block in getattr(entry, 'content', None) or []:
        if isinstance(block, dict):
            html_parts.append(block.get('value') or '')
        else:
            html_parts.append(str(block))
    html = ' '.join(html_parts)
    for pattern in (
        r'<img[^>]+src=["\']([^"\']+)["\']',
        r'<media:content[^>]+url=["\']([^"\']+)["\']',
        r'<media:thumbnail[^>]+url=["\']([^"\']+)["\']',
    ):
        match = re.search(pattern, html, re.I)
        if match:
            found = _first_http_url(match.group(1))
            if found:
                return found
    return ''


def fetch_crypto_news(*, category: str | None = None, force: bool = False) -> list[dict]:
    """Always load the full crypto corpus, then filter by assigned category."""
    articles = _load_all_articles(force=force)
    wanted = (category or '').strip().lower()
    if wanted and wanted not in {'all', '*'}:
        articles = [a for a in articles if (a.get('category') or '').lower() == wanted]
    return articles


def _load_all_articles(*, force: bool = False) -> list[dict]:
    cache_minutes = int(getattr(settings, 'CRYPTO_NEWS_CACHE_MINUTES', 15) or 15)
    cache_key = 'crypto:news:corpus:v3'
    if not force:
        cached = cache.get(cache_key)
        if cached is not None and any((a.get('image_url') or '').strip() for a in cached):
            return cached

    by_id: dict[str, dict] = {}
    # RSS first so CoinTelegraph/CoinDesk photos win over NewsAPI extras.
    for row in _fetch_rss_news(force=True):
        by_id[row['id']] = row

    provider = (getattr(settings, 'CRYPTO_NEWS_PROVIDER', 'rss') or 'rss').lower()
    if provider == 'newsapi' and (getattr(settings, 'CRYPTO_NEWS_API_KEY', '') or '').strip():
        for row in _fetch_newsapi(force=True):
            by_id.setdefault(row['id'], row)

    articles = sorted(by_id.values(), key=lambda a: a.get('published_at') or '', reverse=True)[:80]
    cache.set(cache_key, articles, cache_minutes * 60)
    return articles


def _fetch_newsapi(*, category: str | None = None, force: bool = False) -> list[dict]:
    api_key = (getattr(settings, 'CRYPTO_NEWS_API_KEY', '') or '').strip()
    started = timezone.now()
    try:
        with httpx.Client(timeout=20, follow_redirects=True) as client:
            resp = client.get(
                'https://newsapi.org/v2/everything',
                params={
                    'q': 'bitcoin OR ethereum OR cryptocurrency OR blockchain OR solana',
                    'language': 'en',
                    'sortBy': 'publishedAt',
                    'pageSize': 40,
                    'domains': NEWSAPI_DOMAINS,
                    'apiKey': api_key,
                },
                headers={'User-Agent': 'CapitalBullWave/1.0'},
            )
        if resp.status_code >= 400:
            logger.warning('NewsAPI failed: %s %s', resp.status_code, resp.text[:200])
            return []

        payload = resp.json()
        articles = []
        for item in payload.get('articles') or []:
            title = _clean_html(item.get('title') or '')
            if not title or title.lower() == '[removed]':
                continue
            link = item.get('url') or ''
            summary = _clean_html(item.get('description') or '')[:600]
            source = ((item.get('source') or {}).get('name') or 'NewsAPI')[:120]
            if not _is_crypto_article(title, summary, source, link):
                continue
            cat = _category_for(title, summary)
            published_raw = item.get('publishedAt')
            try:
                published = datetime.fromisoformat(published_raw.replace('Z', '+00:00')) if published_raw else timezone.now()
            except Exception:
                published = timezone.now()
            aid = _stable_id(link, title)
            image = (item.get('urlToImage') or '')[:1000]
            row = {
                'id': aid,
                'title': title[:400],
                'summary': summary,
                'image_url': image,
                'source': source,
                'published_at': published.isoformat(),
                'category': cat,
                'related_cryptocurrencies': _related_assets(title, summary),
                'external_url': link[:500],
            }
            articles.append(row)
            try:
                CryptoNewsArticle.objects.update_or_create(
                    id=aid,
                    defaults={
                        'title': row['title'],
                        'summary': summary,
                        'image_url': row['image_url'],
                        'source': row['source'],
                        'published_at': published,
                        'category': cat,
                        'related_assets': row['related_cryptocurrencies'],
                        'external_url': row['external_url'],
                    },
                )
            except Exception:
                logger.debug('Could not persist NewsAPI row', exc_info=True)
        elapsed = int((timezone.now() - started).total_seconds() * 1000)
        record_provider_call(
            service='news',
            endpoint='newsapi',
            success=True,
            response_ms=elapsed,
            provider_name='newsapi',
        )
        return articles
    except Exception as exc:
        record_provider_call(
            service='news',
            endpoint='newsapi',
            success=False,
            error_type=type(exc).__name__,
            error_message=str(exc)[:400],
            provider_name='newsapi',
        )
        return []


def _fetch_rss_news(*, category: str | None = None, force: bool = False) -> list[dict]:
    articles: list[dict] = []
    started = timezone.now()
    try:
        for source, url in CRYPTO_FEEDS:
            try:
                with httpx.Client(timeout=15, follow_redirects=True) as client:
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
                if not _is_crypto_article(title, summary, source, link):
                    continue
                cat = _category_for(title, summary)
                aid = _stable_id(link, title)
                published = _parse_published(entry)
                row = {
                    'id': aid,
                    'title': title[:400],
                    'summary': summary,
                    'image_url': _entry_image(entry)[:1000],
                    'source': source,
                    'published_at': published.isoformat(),
                    'category': cat,
                    'related_cryptocurrencies': _related_assets(title, summary),
                    'external_url': link[:500],
                }
                articles.append(row)
                try:
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
                except Exception:
                    logger.debug('Could not persist crypto news row', exc_info=True)

        articles.sort(key=lambda a: a['published_at'], reverse=True)
        articles = articles[:80]
        elapsed = int((timezone.now() - started).total_seconds() * 1000)
        try:
            record_provider_call(
                service='news',
                endpoint='rss',
                success=True,
                response_ms=elapsed,
                provider_name='rss',
            )
        except Exception:
            pass
        return articles
    except Exception as exc:
        try:
            record_provider_call(
                service='news',
                endpoint='rss',
                success=False,
                error_type=type(exc).__name__,
                error_message=str(exc)[:400],
                provider_name='rss',
            )
        except Exception:
            pass
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
