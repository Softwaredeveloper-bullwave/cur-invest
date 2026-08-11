import { Link } from 'react-router-dom'
import { Layers, LineChart } from 'lucide-react'
import { FNO_INDICES, FNO_STOCKS } from '../../lib/fno'
import { Badge } from '../../components/ui/Badge'

export function FnoHubPage() {
  return (
    <div className="space-y-8">
      <div>
        <Badge tone="gold">Paper F&O</Badge>
        <h1 className="mt-2 text-2xl font-bold">Futures & Options</h1>
        <p className="mt-1 text-sm text-muted">
          Realtime spot, full strike chain, CE/PE premiums, and index futures — virtual wallet
          only.
        </p>
      </div>

      <section className="space-y-3">
        <div className="flex items-center gap-2">
          <LineChart size={18} className="text-brand-lime" />
          <h2 className="font-semibold">Index Futures & Options</h2>
        </div>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {FNO_INDICES.map((idx) => (
            <Link
              key={idx.symbol}
              to={`/app/fno/${idx.symbol}`}
              className="glass card-hover rounded-2xl p-4"
            >
              <div className="flex items-start justify-between">
                <div>
                  <div className="text-lg font-bold">{idx.symbol}</div>
                  <div className="text-xs text-muted">
                    {idx.label} · {idx.exchange}
                  </div>
                </div>
                <span className="rounded-md bg-brand-lime/15 px-2 py-0.5 text-[10px] font-semibold text-brand-lime">
                  Lot {idx.lotSize}
                </span>
              </div>
              <p className="mt-3 text-xs text-muted">
                Spot · all strikes · weekly expiry · futures @ 12% margin
              </p>
            </Link>
          ))}
        </div>
      </section>

      <section className="space-y-3">
        <div className="flex items-center gap-2">
          <Layers size={18} className="text-brand-gold" />
          <h2 className="font-semibold">Stock Options</h2>
        </div>
        <div className="grid gap-2 sm:grid-cols-3 lg:grid-cols-5">
          {FNO_STOCKS.map((sym) => (
            <Link
              key={sym}
              to={`/app/fno/${sym}`}
              className="rounded-xl border border-white/10 bg-surface/50 px-3 py-3 text-center text-sm font-semibold transition hover:border-brand-lime/40 hover:bg-white/5"
            >
              {sym}
            </Link>
          ))}
        </div>
      </section>
    </div>
  )
}
