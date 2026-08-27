"""Where to paste Forex API keys — never commit real secrets.

Paste into the **server** file: investingapp/backend/.env
Then restart Gunicorn / Django. Flutter never talks to these providers.

Twelve Data (live FX quotes):
  FOREX_API_KEY=your_twelvedata_key
  # aliases also accepted: TWELVE_DATA_API_KEY or FOREX_TWELVEDATA_API_KEY

Alpha Vantage (FX fallback + charts; can reuse the stocks key):
  ALPHA_VANTAGE_API_KEY=your_alphavantage_key
  # optional dedicated FX key: FOREX_ALPHAVANTAGE_API_KEY

Provider order when FOREX_DATA_PROVIDER=auto:
  1. Twelve Data — if a Twelve Data key is set
  2. Alpha Vantage — if an Alpha Vantage key is set (or FOREX_API_KEY is actually an AV key)
  3. ECB Frankfurter — free daily FX rates, no key

  FOREX_DATA_PROVIDER=auto
  FOREX_NEWS_PROVIDER=rss
  FOREX_NEWS_API_KEY=

If Twelve Data rejects the key, the API does **not** show that vendor error.
It fails over to Alpha Vantage, then ECB rates, so Major pairs still load.

Do not put either key in Flutter. The app only calls /api/v1/forex/*.
"""
