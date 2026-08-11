import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { Search } from 'lucide-react'
import { fetchMarketLive, searchStocks } from '../../api/client'
import type { Stock } from '../../api/types'
import { formatInrDecimal, formatPercent } from '../../lib/format'

export function MarketsPage() {
  const [stocks, setStocks] = useState<Stock[]>([])
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void fetchMarketLive()
      .then((m) => setStocks(m.stocks))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => {
    if (!query.trim()) return
    const t = setTimeout(() => {
      void searchStocks(query.trim())
        .then(setStocks)
        .catch(() => {})
    }, 300)
    return () => clearTimeout(t)
  }, [query])

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Markets</h1>
        <p className="text-sm text-muted">
          Live Nifty 50 — open a stock for realtime chart, patterns & paper trade.
        </p>
      </div>

      <div className="relative">
        <Search size={18} className="absolute left-3 top-1/2 -translate-y-1/2 text-muted" />
        <input
          type="search"
          placeholder="Search symbol or name…"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="w-full rounded-xl border border-white/10 bg-surface py-3 pl-10 pr-4 outline-none focus:border-brand-lime/50"
        />
      </div>

      {loading ? (
        <div className="py-12 text-center text-muted">Loading markets…</div>
      ) : (
        <div className="divide-y divide-white/5 rounded-2xl border border-white/10 overflow-hidden">
          {stocks.map((s) => (
            <Link
              key={s.symbol}
              to={`/app/trade/${s.symbol}`}
              className="flex items-center justify-between bg-surface/50 px-4 py-3 transition hover:bg-white/5"
            >
              <div>
                <div className="font-semibold">{s.symbol}</div>
                <div className="text-xs text-muted">{s.name}</div>
              </div>
              <div className="text-right">
                <div className="font-medium">{formatInrDecimal(Number(s.ltp))}</div>
                <div
                  className={`text-xs ${Number(s.changePercent) >= 0 ? 'text-success' : 'text-danger'}`}
                >
                  {formatPercent(Number(s.changePercent))}
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </div>
  )
}
