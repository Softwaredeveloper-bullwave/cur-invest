# Crypto real-data APIs (AWS `.env`)

Flutter never calls these. Django `/api/v1/crypto/*` does.

Add keys on the **EC2** `investingapp/backend/.env`, then:

```bash
cd ~/cur-invest/investingapp/backend
source venv/bin/activate
# paste keys into .env
bash deploy/restart_backend.sh
curl -s https://api.capitalbullwave.com/api/v1/crypto/health/
```

---

## 1) Market prices, charts, screener, top coins (required)

**Provider:** CoinGecko  
**Get key:** https://www.coingecko.com/en/api/pricing (free Demo key works)

```env
CRYPTO_DATA_PROVIDER=coingecko
CRYPTO_API_KEY=CG-xxxxxxxxxxxxxxxx
# Leave blank for auto base URL, or set explicitly:
# Demo:  https://api.coingecko.com/api/v3
# Pro:   https://pro-api.coingecko.com/api/v3
CRYPTO_API_BASE_URL=
CRYPTO_API_TIMEOUT=20
CRYPTO_MARKET_CACHE_SECONDS=60
CRYPTO_USD_INR_RATE=83
CRYPTO_TRADING_ENABLED=False
```

**Powers:**
| App feature | Backend endpoint | External call |
|-------------|------------------|---------------|
| Crypto home overview | `GET /api/v1/crypto/overview/` | `/global`, trending, Fear&Greed |
| Top coins / list | `GET /api/v1/crypto/assets/?top=1` | `/coins/markets` |
| Coin detail | `GET /api/v1/crypto/assets/{id}/` | `/coins/{id}` |
| Charts (1H–ALL) | `GET /api/v1/crypto/assets/{id}/chart/?period=1D` | `/coins/{id}/market_chart` |
| Search | `GET /api/v1/crypto/search/?q=btc` | `/search` |
| Screener / movers | `GET /api/v1/crypto/screener/`, `/movers/` | `/coins/markets` |

Without `CRYPTO_API_KEY`, CoinGecko often rate-limits or blocks — charts/news look empty.

---

## 2) Fear & Greed (optional, no key)

https://api.alternative.me/fng/ — used inside overview. No env needed.

---

## 3) Crypto news (RSS by default — no key)

```env
CRYPTO_NEWS_PROVIDER=rss
CRYPTO_NEWS_CACHE_MINUTES=15
```

Feeds already wired: CoinDesk, CoinTelegraph, Bitcoin Magazine.

**If you have a paid news API** (CryptoCompare, NewsAPI, Messari, etc.), put:

```env
CRYPTO_NEWS_PROVIDER=cryptocompare   # or your provider name after we wire it
CRYPTO_NEWS_API_KEY=your_key_here
```

Today only `rss` is implemented. Share your news provider name + docs and we can plug it in.

**Flutter:** `GET /api/v1/crypto/news/?category=Bitcoin`

---

## 4) What you put in AWS `.env` if you already have keys

```env
# Paste your CoinGecko Demo/Pro key
CRYPTO_API_KEY=PASTE_YOUR_KEY

# Optional news key (only if not using RSS)
# CRYPTO_NEWS_API_KEY=PASTE_NEWS_KEY
# CRYPTO_NEWS_PROVIDER=rss
```

Then restart gunicorn. No Flutter rebuild needed for keys.

---

## 5) Quick verify

```bash
# After login JWT:
curl -H "Authorization: Bearer ACCESS" \
  https://api.capitalbullwave.com/api/v1/crypto/overview/

curl -H "Authorization: Bearer ACCESS" \
  "https://api.capitalbullwave.com/api/v1/crypto/assets/bitcoin/chart/?period=1D"

curl -H "Authorization: Bearer ACCESS" \
  https://api.capitalbullwave.com/api/v1/crypto/news/
```

You should see live `current_price`, chart `prices[]`, and news `results[]`.

---

## 6) Indian indices “pull to refresh” note

Home indices come from `GET /api/v1/home/` → `MarketIndex` table + live refresh.  
Also ensure Kotak / Yahoo market provider is working (`KOTAK_NEO_ACCESS_TOKEN` or fallbacks).  
On empty DB, server now auto-seeds NIFTY/SENSEX/BANKNIFTY rows.
