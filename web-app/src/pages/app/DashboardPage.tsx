import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import { ArrowRight, TrendingUp } from 'lucide-react'
import { Badge } from '../../components/ui/Badge'
import { Button } from '../../components/ui/Button'
import {
  fetchMarketLive,
  fetchPaperTrades,
  fetchPortfolioAnalytics,
  fetchPracticeWallet,
} from '../../api/client'
import type { PaperTrade, Stock } from '../../api/types'
import { formatInr, formatInrDecimal, formatPercent } from '../../lib/format'

export function DashboardPage() {
  const [wallet, setWallet] = useState(0)
  const [pnl, setPnl] = useState(0)
  const [pnlPct, setPnlPct] = useState(0)
  const [stocks, setStocks] = useState<Stock[]>([])
  const [trades, setTrades] = useState<PaperTrade[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void (async () => {
      try {
        const [w, m, p, t] = await Promise.all([
          fetchPracticeWallet(),
          fetchMarketLive(),
          fetchPortfolioAnalytics().catch(() => null),
          fetchPaperTrades().catch(() => []),
        ])
        setWallet(w.balance)
        setStocks(m.stocks.slice(0, 5))
        if (p) {
          setPnl(p.pnl ?? 0)
          setPnlPct(p.pnlPercent ?? 0)
        }
        setTrades(t.slice(0, 5))
      } finally {
        setLoading(false)
      }
    })()
  }, [])

  if (loading) {
    return (
      <div className="flex justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-lime border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <Badge tone="gold">Live trading — Launching soon</Badge>
          <h1 className="mt-2 text-2xl font-bold">Practice Dashboard</h1>
          <p className="text-sm text-muted">Virtual money only — zero risk learning.</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <Button to="/app/markets">
            Trade now <ArrowRight size={16} />
          </Button>
          <Button to="/app/fno" variant="secondary">
            F&O desk
          </Button>
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div className="glass rounded-2xl p-5">
          <p className="text-sm text-muted">Practice balance</p>
          <p className="mt-1 text-2xl font-bold text-brand-lime">{formatInr(wallet)}</p>
        </div>
        <div className="glass rounded-2xl p-5">
          <p className="text-sm text-muted">Portfolio P&L</p>
          <p className={`mt-1 text-2xl font-bold ${pnl >= 0 ? 'text-success' : 'text-danger'}`}>
            {formatInrDecimal(pnl)}
          </p>
        </div>
        <div className="glass rounded-2xl p-5">
          <p className="text-sm text-muted">Return</p>
          <p className={`mt-1 text-2xl font-bold ${pnlPct >= 0 ? 'text-success' : 'text-danger'}`}>
            {formatPercent(pnlPct)}
          </p>
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="glass rounded-2xl p-5">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="font-semibold">Trending stocks</h2>
            <Link to="/app/markets" className="text-sm text-brand-lime">
              View all
            </Link>
          </div>
          <div className="space-y-2">
            {stocks.map((s) => (
              <Link
                key={s.symbol}
                to={`/app/trade/${s.symbol}`}
                className="flex items-center justify-between rounded-xl bg-midnight/50 px-3 py-2 transition hover:bg-white/5"
              >
                <div>
                  <div className="font-medium">{s.symbol}</div>
                  <div className="text-xs text-muted">{s.name}</div>
                </div>
                <div className="text-right">
                  <div>{formatInrDecimal(Number(s.ltp))}</div>
                  <div
                    className={`text-xs ${Number(s.changePercent) >= 0 ? 'text-success' : 'text-danger'}`}
                  >
                    {formatPercent(Number(s.changePercent))}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>

        <div className="glass rounded-2xl p-5">
          <h2 className="mb-4 font-semibold">Recent paper trades</h2>
          {trades.length === 0 ? (
            <p className="text-sm text-muted">No trades yet. Pick a stock from Markets.</p>
          ) : (
            <div className="space-y-2">
              {trades.map((t) => (
                <div
                  key={t.id}
                  className="flex justify-between rounded-xl bg-midnight/50 px-3 py-2 text-sm"
                >
                  <span>
                    {t.side} {t.quantity} × {t.symbol}
                  </span>
                  <span className="text-muted">{formatInrDecimal(Number(t.price))}</span>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}

export function LiveTradingPage() {
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center text-center">
      <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-brand-gold/15 text-brand-gold">
        <TrendingUp size={32} />
      </div>
      <Badge tone="gold">Launching soon</Badge>
      <h1 className="mt-4 text-3xl font-bold">Live Trading</h1>
      <p className="mt-3 max-w-md text-muted">
        Real NSE/BSE execution, Demat account, and UPI deposits are coming after our SEBI license
        approval. Keep practicing with paper trading until then.
      </p>
      <div className="mt-8 flex gap-3">
        <Button to="/app/markets">Continue paper trading</Button>
        <Button to="/" variant="secondary">
          Back to home
        </Button>
      </div>
    </div>
  )
}
