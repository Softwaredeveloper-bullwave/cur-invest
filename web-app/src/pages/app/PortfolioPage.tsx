import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import {
  fetchOptionHoldings,
  fetchOptionTrades,
  fetchPaperTrades,
  fetchPortfolioAnalytics,
  fetchPracticeWallet,
} from '../../api/client'
import type { OptionHolding, OptionTrade, PaperTrade } from '../../api/types'
import { formatInr, formatInrDecimal, formatPercent } from '../../lib/format'

export function PortfolioPage() {
  const [wallet, setWallet] = useState(0)
  const [pnl, setPnl] = useState(0)
  const [pnlPct, setPnlPct] = useState(0)
  const [holdings, setHoldings] = useState<
    { symbol: string; name: string; quantity: number; ltp: number; avgPrice: number }[]
  >([])
  const [optionHoldings, setOptionHoldings] = useState<OptionHolding[]>([])
  const [trades, setTrades] = useState<PaperTrade[]>([])
  const [optionTrades, setOptionTrades] = useState<OptionTrade[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    void (async () => {
      try {
        const [w, p, t, oh, ot] = await Promise.all([
          fetchPracticeWallet(),
          fetchPortfolioAnalytics().catch(() => null),
          fetchPaperTrades().catch(() => []),
          fetchOptionHoldings().catch(() => ({ holdings: [] })),
          fetchOptionTrades().catch(() => ({ trades: [] })),
        ])
        setWallet(w.balance)
        if (p) {
          setPnl(p.pnl ?? 0)
          setPnlPct(p.pnlPercent ?? 0)
          setHoldings(
            ((p.holdings as Record<string, unknown>[]) ?? []).map((h) => ({
              symbol: String(h.symbol ?? ''),
              name: String(h.name ?? ''),
              quantity: Number(h.quantity ?? 0),
              ltp: Number(h.ltp ?? 0),
              avgPrice: Number(h.avgPrice ?? h.avg_price ?? 0),
            })),
          )
        }
        setTrades(t)
        setOptionHoldings(oh.holdings ?? [])
        setOptionTrades(ot.trades ?? [])
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
      <div className="flex flex-wrap items-end justify-between gap-3">
        <h1 className="text-2xl font-bold">Paper Portfolio</h1>
        <Link to="/app/fno" className="text-sm text-brand-lime hover:underline">
          Trade F&O →
        </Link>
      </div>

      <div className="grid gap-4 sm:grid-cols-3">
        <div className="glass rounded-2xl p-4">
          <p className="text-xs text-muted">Cash balance</p>
          <p className="text-xl font-bold text-brand-lime">{formatInr(wallet)}</p>
        </div>
        <div className="glass rounded-2xl p-4">
          <p className="text-xs text-muted">Equity P&L</p>
          <p className={`text-xl font-bold ${pnl >= 0 ? 'text-success' : 'text-danger'}`}>
            {formatInrDecimal(pnl)}
          </p>
        </div>
        <div className="glass rounded-2xl p-4">
          <p className="text-xs text-muted">Equity return</p>
          <p className={`text-xl font-bold ${pnlPct >= 0 ? 'text-success' : 'text-danger'}`}>
            {formatPercent(pnlPct)}
          </p>
        </div>
      </div>

      <div className="glass rounded-2xl p-5">
        <h2 className="mb-4 font-semibold">F&O positions</h2>
        {optionHoldings.length === 0 ? (
          <p className="text-sm text-muted">
            No futures/options lots yet.{' '}
            <Link to="/app/fno" className="text-brand-lime">
              Open F&O desk
            </Link>
          </p>
        ) : (
          <div className="space-y-2">
            {optionHoldings.map((h) => (
              <Link
                key={`${h.underlying}-${h.strike}-${h.optionType}-${h.expiry}`}
                to={`/app/fno/${h.underlying}${h.optionType === 'FU' ? '?tab=futures' : ''}`}
                className="flex justify-between gap-3 rounded-xl bg-midnight/50 px-3 py-2 text-sm hover:bg-white/5"
              >
                <span>
                  {h.contractLabel} · {h.quantity} lot{h.quantity === 1 ? '' : 's'}
                </span>
                <span className="text-muted">
                  Avg {formatInrDecimal(Number(h.avgPremium))}
                </span>
              </Link>
            ))}
          </div>
        )}
      </div>

      <div className="glass rounded-2xl p-5">
        <h2 className="mb-4 font-semibold">Equity holdings</h2>
        {holdings.length === 0 ? (
          <p className="text-sm text-muted">
            No equity holdings yet.{' '}
            <Link to="/app/markets" className="text-brand-lime">
              Buy from Markets
            </Link>
          </p>
        ) : (
          <div className="space-y-2">
            {holdings.map((h) => (
              <Link
                key={h.symbol}
                to={`/app/trade/${h.symbol}`}
                className="flex justify-between rounded-xl bg-midnight/50 px-3 py-2 text-sm hover:bg-white/5"
              >
                <span>
                  {h.symbol} · {h.quantity} shares
                </span>
                <span>{formatInrDecimal(h.ltp * h.quantity)}</span>
              </Link>
            ))}
          </div>
        )}
      </div>

      <div className="glass rounded-2xl p-5">
        <h2 className="mb-4 font-semibold">F&O order history</h2>
        {optionTrades.length === 0 ? (
          <p className="text-sm text-muted">No F&O orders yet.</p>
        ) : (
          <div className="space-y-2">
            {optionTrades.map((t) => (
              <div
                key={t.id}
                className="flex justify-between gap-3 rounded-xl bg-midnight/50 px-3 py-2 text-sm"
              >
                <span>
                  <span className={t.side === 'BUY' ? 'text-success' : 'text-danger'}>{t.side}</span>{' '}
                  {t.contractLabel} × {t.quantity}
                </span>
                <span className="text-muted">{formatInrDecimal(Number(t.amountInr))}</span>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="glass rounded-2xl p-5">
        <h2 className="mb-4 font-semibold">Equity order history</h2>
        {trades.length === 0 ? (
          <p className="text-sm text-muted">No equity orders yet.</p>
        ) : (
          <div className="space-y-2">
            {trades.map((t) => (
              <div
                key={t.id}
                className="flex justify-between rounded-xl bg-midnight/50 px-3 py-2 text-sm"
              >
                <span>
                  <span className={t.side === 'BUY' ? 'text-success' : 'text-danger'}>{t.side}</span>{' '}
                  {t.quantity} {t.symbol} @ {formatInrDecimal(Number(t.price))}
                </span>
                <span className="text-muted">{new Date(t.createdAt).toLocaleDateString('en-IN')}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
