import type { Candle } from '../../api/types'
import { computeTechnicals, detectPatterns } from '../../lib/indicators'
import { formatInrDecimal } from '../../lib/format'

type Props = {
  candles: Candle[]
  quote?: {
    open?: number
    high?: number
    low?: number
    previousClose?: number
    volume?: number
    ltp: number
  } | null
}

export function MarketAnalysisPanel({ candles, quote }: Props) {
  const tech = computeTechnicals(candles)
  const patterns = detectPatterns(candles)
  const last = candles[candles.length - 1]

  const ohlc = [
    { label: 'Open', value: quote?.open ?? last?.open },
    { label: 'High', value: quote?.high ?? last?.high },
    { label: 'Low', value: quote?.low ?? last?.low },
    { label: 'Prev', value: quote?.previousClose },
  ]

  return (
    <div className="space-y-4">
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        {ohlc.map((row) => (
          <div key={row.label} className="rounded-xl border border-white/10 bg-surface/50 px-3 py-2">
            <div className="text-[10px] uppercase tracking-wide text-muted">{row.label}</div>
            <div className="mt-0.5 text-sm font-semibold">
              {row.value != null ? formatInrDecimal(Number(row.value)) : '—'}
            </div>
          </div>
        ))}
      </div>

      <div>
        <h3 className="mb-2 text-sm font-semibold text-white">Indicators</h3>
        <div className="flex flex-wrap gap-2">
          <Chip
            label="RSI"
            value={String(tech.rsi)}
            tone={tech.rsi >= 70 ? 'danger' : tech.rsi <= 30 ? 'success' : 'neutral'}
          />
          <Chip label="MACD" value={tech.macdSignal} tone={tech.macdSignal === 'Buy' ? 'success' : 'danger'} />
          <Chip label="Trend" value={tech.trend} tone={tech.trend.includes('Up') || tech.trend === 'Bullish' ? 'success' : 'danger'} />
          <Chip label="SMA 20" value={formatInrDecimal(tech.sma20)} />
          <Chip label="SMA 50" value={formatInrDecimal(tech.sma50)} />
          <Chip label="SMA 200" value={formatInrDecimal(tech.sma200)} />
        </div>
        <p className="mt-2 text-xs text-muted">
          Chart overlays: <span className="text-sky-400">SMA 20</span> ·{' '}
          <span className="text-amber-400">SMA 50</span> · volume histogram
        </p>
      </div>

      <div>
        <h3 className="mb-2 text-sm font-semibold text-white">Candlestick patterns</h3>
        {patterns.length === 0 ? (
          <p className="text-sm text-muted">No strong patterns on recent bars.</p>
        ) : (
          <ul className="space-y-2">
            {patterns.map((p) => (
              <li
                key={`${p.name}-${p.atIndex}`}
                className="flex items-start justify-between gap-3 rounded-xl border border-white/10 bg-surface/50 px-3 py-2"
              >
                <div>
                  <div className="text-sm font-medium">{p.name}</div>
                  <div className="text-xs text-muted">{p.description}</div>
                </div>
                <span
                  className={`shrink-0 rounded-md px-2 py-0.5 text-[11px] font-semibold ${
                    p.signal === 'Bullish'
                      ? 'bg-success/15 text-success'
                      : p.signal === 'Bearish'
                        ? 'bg-danger/15 text-danger'
                        : 'bg-white/10 text-muted'
                  }`}
                >
                  {p.signal}
                </span>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  )
}

function Chip({
  label,
  value,
  tone = 'neutral',
}: {
  label: string
  value: string
  tone?: 'success' | 'danger' | 'neutral'
}) {
  const color =
    tone === 'success' ? 'text-success' : tone === 'danger' ? 'text-danger' : 'text-white'
  return (
    <span className="inline-flex items-center gap-1.5 rounded-lg border border-white/10 bg-surface px-2.5 py-1 text-xs">
      <span className="text-muted">{label}</span>
      <span className={`font-semibold ${color}`}>{value}</span>
    </span>
  )
}
