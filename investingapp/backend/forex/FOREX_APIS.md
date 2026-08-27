"""Where to paste your Forex API keys — never commit real secrets.

Paste into: investingapp/backend/.env  (then restart Django)

  FOREX_DATA_PROVIDER=auto
  FOREX_API_KEY=your_market_data_key
  FOREX_API_BASE_URL=https://api.twelvedata.com
  FOREX_NEWS_PROVIDER=newsapi
  FOREX_NEWS_API_KEY=your_newsapi_key

Defaults:
  - No FOREX_API_KEY → ECB Frankfurter (free FX rates, no key)
  - FOREX_API_KEY set → Twelve Data compatible REST (quote + time_series)
  - FOREX_NEWS_API_KEY empty → ForexLive / FXStreet / DailyFX RSS
  - FOREX_NEWS_API_KEY set and FOREX_NEWS_PROVIDER=newsapi → NewsAPI

Flutter never talks to these providers. It only calls /api/v1/forex/*.
"""
