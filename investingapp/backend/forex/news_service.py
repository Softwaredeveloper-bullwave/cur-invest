"""Forex news via MarketAux, RSS, or NewsAPI. Keys stay in .env — Flutter never sees them."""

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
from .models import ForexNewsArticle
from .pairs import PAIR_BY_ID, normalize_pair_id

logger = logging.getLogger('bullwave.forex')
IST = ZoneInfo('Asia/Kolkata')

FOREX_FEEDS = (
    ('InvestingLive', 'https://investinglive.com/feed/rss/'),
    ('FXStreet', 'https://www.fxstreet.com/rss/news'),
    ('Investing.com', 'https://www.investing.com/rss/news_1.rss'),
)

CATEGORIES = ('All', 'USD', 'EUR', 'GBP', 'JPY', 'INR', 'Majors', 'Central Banks', 'Market Analysis')

RSS_HEADERS = {
    'User-Agent': (
        'Mozilla/5.0 (compatible; CapitalBullWave/1.0; +https://capitalbullwave.com)'
    ),
    'Accept': 'application/rss+xml, application/xml, text/xml, */*',
}

_CATEGORY_KEYWORDS = {
    'usd': ('usd', 'dollar', 'dxy', 'greenback', 'usdinr', 'usdjpy', 'eurusd', 'gbpusd'),
    'eur': ('eur', 'euro', 'eurusd', 'eurgbp', 'eurjpy', 'eurinr'),
    'gbp': ('gbp', 'pound', 'sterling', 'gbpusd', 'gbpjpy', 'gbpinr'),
    'jpy': ('jpy', 'yen', 'usdjpy', 'eurjpy', 'gbpjpy'),
    'inr': ('inr', 'rupee', 'usdinr', 'eurinr', 'gbpinr'),
    'majors': ('eurusd', 'gbpusd', 'usdjpy', 'usdchf', 'audusd', 'usdcad', 'nzdusd', 'major'),
    'central banks': (
        'fed',
        'ecb',
        'boe',
        'boj',
        'rbi',
        'fomc',
        'interest rate',
        'rate hike',
        'rate cut',
    ),
}


def _stable_id(url: str, title: str) -> str:
    return hashlib.sha256((url or title).encode('utf-8', errors='ignore')).hexdigest()[:32]


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
        ('Central Banks', r'\b(fed|ecb|boe|boj|rbi|fomc|interest rate|rate hike|rate cut)\b'),
        ('USD', r'\b(dollar|usd|greenback|dxy)\b'),
        ('EUR', r'\b(euro|eur)\b'),
        ('GBP', r'\b(pound|sterling|gbp)\b'),
        ('JPY', r'\b(yen|jpy)\b'),
        ('INR', r'\b(rupee|inr)\b'),
        ('Majors', r'\b(eurusd|gbpusd|usdjpy|major)\b'),
    )
    for cat, pattern in rules:
        if re.search(pattern, text, re.I):
            return cat
    return 'Market Analysis'


def _first_http_url(value) -> str:
    if isinstance(value, str):
        url = value.strip()
        if url.startswith('//'):
            url = f'https:{url}'
        if url.startswith(('http://', 'https://')):
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
    for attr in ('media_content', 'media_thumbnail', 'image', 'enclosures'):
        url = _first_http_url(getattr(entry, attr, None))
        if url:
            return url
    html = ' '.join([getattr(entry, 'summary', '') or '', getattr(entry, 'description', '') or ''])
    match = re.search(r'<img[^>]+src=["\']([^"\']+)["\']', html, re.I)
    return _first_http_url(match.group(1) if match else '')


def _article_blob(article: dict) -> str:
    related = ' '.join(str(item) for item in (article.get('related_pairs') or []))
    return (
        f"{article.get('title') or ''} {article.get('summary') or ''} "
        f"{article.get('category') or ''} {related}"
    ).lower()


def _article_matches_category(article: dict, wanted: str) -> bool:
    if not wanted or wanted in {'all', '*'}:
        return True
    if (article.get('category') or '').lower() == wanted:
        return True
    keywords = _CATEGORY_KEYWORDS.get(wanted)
    blob = _article_blob(article)
    if not keywords:
        return wanted in blob
    return any(token in blob for token in keywords)


def fetch_forex_news(*, category: str | None = None, force: bool = False) -> list[dict]:
    articles = _load_all_articles(force=force)
    wanted = (category or '').strip().lower()
    if wanted and wanted not in {'all', '*'}:
        articles = [a for a in articles if _article_matches_category(a, wanted)]
    return articles


def _news_api_key() -> str:
    return (
        (getattr(settings, 'FOREX_NEWS_API_KEY', '') or '')
        or (getattr(settings, 'MARKETAUX_API_TOKEN', '') or '')
    ).strip()


def _load_all_articles(*, force: bool = False) -> list[dict]:
    cache_minutes = int(getattr(settings, 'FOREX_NEWS_CACHE_MINUTES', 15) or 15)
    cache_key = 'forex:news:corpus:v3'
    if not force:
        cached = cache.get(cache_key)
        if cached:
            return cached
    by_id: dict[str, dict] = {}
    provider = (getattr(settings, 'FOREX_NEWS_PROVIDER', 'rss') or 'rss').lower()
    api_key = _news_api_key()
    if provider == 'marketaux' and api_key:
        for row in _fetch_marketaux():
            by_id[row['id']] = row
    for row in _fetch_rss():
        by_id.setdefault(row['id'], row)
    if provider == 'newsapi' and api_key:
        for row in _fetch_newsapi():
            by_id.setdefault(row['id'], row)
    if not by_id:
        for row in _articles_from_db():
            by_id[row['id']] = row
    articles = sorted(by_id.values(), key=lambda a: a.get('published_at') or '', reverse=True)[:80]
    if articles:
        cache.set(cache_key, articles, cache_minutes * 60)
    return articles


def _articles_from_db() -> list[dict]:
    try:
        return [
            {
                'id': a.id,
                'title': a.title,
                'summary': a.summary,
                'image_url': a.image_url,
                'source': a.source,
                'published_at': a.published_at.isoformat(),
                'category': a.category,
                'related_pairs': a.related_pairs,
                'external_url': a.external_url,
                'stale': True,
            }
            for a in ForexNewsArticle.objects.all()[:50]
        ]
    except Exception:
        return []


def _pairs_from_entities(entities) -> list[str]:
    found: list[str] = []
    for entity in entities or []:
        if not isinstance(entity, dict):
            continue
        kind = (entity.get('type') or entity.get('asset_type') or '').lower()
        if kind and kind not in {'currency', 'forex'}:
            continue
        symbol = (entity.get('symbol') or '').replace('/', '').replace('-', '').replace('_', '')
        pair_id = normalize_pair_id(symbol)
        if pair_id in PAIR_BY_ID and pair_id not in found:
            found.append(pair_id)
    return found[:6]


def _persist_article(row: dict, published: datetime) -> None:
    try:
        ForexNewsArticle.objects.update_or_create(
            id=row['id'],
            defaults={
                'title': row['title'],
                'summary': row['summary'],
                'image_url': row.get('image_url') or '',
                'source': row['source'],
                'published_at': published,
                'category': row['category'],
                'related_pairs': row.get('related_pairs') or [],
                'external_url': row['external_url'],
            },
        )
    except Exception:
        logger.debug('Could not persist forex news row', exc_info=True)


def _fetch_rss() -> list[dict]:
    articles: list[dict] = []
    started = timezone.now()
    try:
        for source, url in FOREX_FEEDS:
            try:
                with httpx.Client(timeout=15, follow_redirects=True) as client:
                    resp = client.get(url, headers=RSS_HEADERS)
                if resp.status_code != 200:
                    continue
                feed = feedparser.parse(resp.text)
            except Exception:
                logger.debug('Forex news feed failed: %s', source, exc_info=True)
                continue
            for entry in feed.entries[:20]:
                title = _clean_html(getattr(entry, 'title', '') or '')
                if not title:
                    continue
                link = getattr(entry, 'link', '') or ''
                summary = _clean_html(
                    getattr(entry, 'summary', '') or getattr(entry, 'description', '') or ''
                )[:600]
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
                    'related_pairs': [],
                    'external_url': link[:500],
                }
                articles.append(row)
                try:
                    ForexNewsArticle.objects.update_or_create(
                        id=aid,
                        defaults={
                            'title': row['title'],
                            'summary': summary,
                            'image_url': row['image_url'],
                            'source': source,
                            'published_at': published,
                            'category': cat,
                            'related_pairs': [],
                            'external_url': row['external_url'],
                        },
                    )
                except Exception:
                    logger.debug('Could not persist forex news row', exc_info=True)
        elapsed = int((timezone.now() - started).total_seconds() * 1000)
        record_provider_call(
            service='news', endpoint='rss', success=True, response_ms=elapsed, provider_name='rss'
        )
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
        return [
            {
                'id': a.id,
                'title': a.title,
                'summary': a.summary,
                'image_url': a.image_url,
                'source': a.source,
                'published_at': a.published_at.isoformat(),
                'category': a.category,
                'related_pairs': a.related_pairs,
                'external_url': a.external_url,
                'stale': True,
            }
            for a in ForexNewsArticle.objects.all()[:50]
        ]


def _fetch_marketaux() -> list[dict]:
    api_key = _news_api_key()
    base = (
        getattr(settings, 'FOREX_NEWS_API_BASE_URL', '') or 'https://api.marketaux.com/v1'
    ).rstrip('/')
    started = timezone.now()
    try:
        with httpx.Client(timeout=20, follow_redirects=True) as client:
            resp = client.get(
                f'{base}/news/all',
                params={
                    'api_token': api_key,
                    'entity_types': 'currency',
                    'search': 'forex OR EURUSD OR "US dollar" OR rupee',
                    'language': 'en',
                    'limit': 10,
                },
                headers={'User-Agent': 'CapitalBullWave/1.0 (forex-news)'},
            )
        elapsed = int((timezone.now() - started).total_seconds() * 1000)
        if resp.status_code >= 400:
            logger.warning('MarketAux forex news failed: %s %s', resp.status_code, resp.text[:200])
            record_provider_call(
                service='news',
                endpoint='marketaux',
                success=False,
                status_code=resp.status_code,
                response_ms=elapsed,
                error_type='http_error',
                error_message=f'MarketAux HTTP {resp.status_code}',
                provider_name='marketaux',
            )
            return []
        payload = resp.json() if resp.content else {}
        articles: list[dict] = []
        for item in payload.get('data') or []:
            if not isinstance(item, dict):
                continue
            title = _clean_html(item.get('title') or '')
            if not title:
                continue
            link = item.get('url') or ''
            summary = _clean_html(item.get('snippet') or item.get('description') or '')[:600]
            related = _pairs_from_entities(item.get('entities'))
            published_raw = item.get('published_at')
            try:
                published = (
                    datetime.fromisoformat(str(published_raw).replace('Z', '+00:00'))
                    if published_raw
                    else timezone.now()
                )
            except Exception:
                published = timezone.now()
            aid = (item.get('uuid') or _stable_id(link, title))[:32]
            source = (item.get('source') or 'MarketAux')[:120]
            blob = f'{title} {summary} {" ".join(related)}'
            row = {
                'id': aid,
                'title': title[:400],
                'summary': summary,
                'image_url': (item.get('image_url') or '')[:1000],
                'source': source,
                'published_at': published.isoformat(),
                'category': _category_for(blob, blob),
                'related_pairs': related,
                'external_url': link[:500],
            }
            articles.append(row)
            _persist_article(row, published)
        record_provider_call(
            service='news',
            endpoint='marketaux',
            success=True,
            status_code=resp.status_code,
            response_ms=elapsed,
            provider_name='marketaux',
        )
        return articles
    except Exception as exc:
        record_provider_call(
            service='news',
            endpoint='marketaux',
            success=False,
            error_type=type(exc).__name__,
            error_message=str(exc)[:400],
            provider_name='marketaux',
        )
        logger.debug('Forex MarketAux fetch failed', exc_info=True)
        return []


def _fetch_newsapi() -> list[dict]:
    api_key = _news_api_key()
    try:
        with httpx.Client(timeout=20, follow_redirects=True) as client:
            resp = client.get(
                'https://newsapi.org/v2/everything',
                params={
                    'q': 'forex OR "foreign exchange" OR EURUSD OR "US dollar" OR rupee',
                    'language': 'en',
                    'sortBy': 'publishedAt',
                    'pageSize': 30,
                    'domains': 'forexlive.com,fxstreet.com,dailyfx.com,reuters.com,bloomberg.com',
                    'apiKey': api_key,
                },
            )
        data = resp.json() if resp.content else {}
        articles = []
        for item in data.get('articles') or []:
            title = _clean_html(item.get('title') or '')
            if not title:
                continue
            link = item.get('url') or ''
            summary = _clean_html(item.get('description') or '')[:600]
            published_raw = item.get('publishedAt')
            try:
                published = (
                    datetime.fromisoformat(published_raw.replace('Z', '+00:00'))
                    if published_raw
                    else timezone.now()
                )
            except Exception:
                published = timezone.now()
            aid = _stable_id(link, title)
            articles.append(
                {
                    'id': aid,
                    'title': title[:400],
                    'summary': summary,
                    'image_url': (item.get('urlToImage') or '')[:1000],
                    'source': ((item.get('source') or {}).get('name') or 'NewsAPI')[:120],
                    'published_at': published.isoformat(),
                    'category': _category_for(title, summary),
                    'related_pairs': [],
                    'external_url': link[:500],
                }
            )
        return articles
    except Exception:
        logger.debug('Forex NewsAPI fetch failed', exc_info=True)
        return []
