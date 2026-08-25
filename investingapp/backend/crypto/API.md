# Crypto API documentation (additive to existing /api/v1 style)

## Auth
All endpoints require JWT `Authorization: Bearer <access>` unless noted.

## Market preference
- `GET /api/v1/crypto/market-preference/`
- `PUT|PATCH /api/v1/crypto/market-preference/`
  Body: `{ indian_market_enabled, crypto_market_enabled, active_market? }`
  Sets `has_completed_selection=true`. At least one market required.

## Market data
- `GET /api/v1/crypto/overview/` — global mcap, BTC dominance, fear/greed, trending
- `GET /api/v1/crypto/assets/?page=&page_size=&vs_currency=&order=&top=1`
- `GET /api/v1/crypto/assets/{asset_id}/`
- `GET /api/v1/crypto/assets/{asset_id}/chart/?period=1H|1D|1W|1M|3M|1Y|ALL`
- `GET /api/v1/crypto/search/?q=`
- `GET /api/v1/crypto/screener/?sort=&min_price=&max_price=&min_market_cap=&…`
- `GET /api/v1/crypto/movers/?type=gainers|losers|volume|trending`

Errors: `503` with `{ detail, retryable }` when provider unavailable.

## Watchlist
- `GET /api/v1/crypto/watchlist/`
- `POST /api/v1/crypto/watchlist/` `{ asset_id }`
- `DELETE /api/v1/crypto/watchlist/{id}/`

## News
- `GET /api/v1/crypto/news/?category=` — cached RSS (CoinDesk, CoinTelegraph, …)

## Paper portfolio (VIRTUAL ONLY)
- `GET /api/v1/crypto/portfolio/`
- `GET /api/v1/crypto/wallet/`
- `POST /api/v1/crypto/paper-orders/` `{ asset_id, side: BUY|SELL, quantity }`
- `GET /api/v1/crypto/transactions/`
- `GET /api/v1/crypto/trading-status/` — live trading disabled until compliance

## Notifications
- `GET|PUT /api/v1/crypto/notification-preferences/`
- `GET|POST /api/v1/crypto/price-alerts/`

## Health
- `GET /api/v1/crypto/health/` — market_data / news / ai status

## Admin panel
- `GET /api/v1/admin-panel/crypto/overview/`
- `GET /api/v1/admin-panel/crypto/transactions/`

## Rate limits / caching
Provider responses cached via `CRYPTO_MARKET_CACHE_SECONDS` / `CRYPTO_NEWS_CACHE_MINUTES`.
External keys stay server-side only (`CRYPTO_API_KEY`, etc.).
