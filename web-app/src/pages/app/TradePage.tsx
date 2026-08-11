import { useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { CandleChart } from '../../components/charts/CandleChart'
import { MarketAnalysisPanel } from '../../components/charts/MarketAnalysisPanel'
import { ApiError, fetchCandles, fetchQuote, placePaperTrade } from '../../api/client'
import type { Candle, ChartInterval, Stock } from '../../api/types'
import { formatInrDecimal, formatPercent } from '../../lib/format'

const INTERVALS: { id: ChartInterval; label: string }[] = [
  { id: '1m', label: '1m' },
  { id: '5m', label: '5m' },
  { id: '30m', label: '30m' },
  { id: '1h', label: '1H' },
  { id: '1d', label: '1D' },
  { id: '90d', label: '3M' },
]

const QUOTE_POLL_MS = 15_000
const CANDLE_POLL_MS = 60_000

export function TradePage() {
  const { symbol = '' } = useParams()
  const navigate = useNavigate()
  const sym = symbol.toUpperCase()

  const [stock, setStock] = useState<Stock | null>(null)
  const [candles, setCandles] = useState<Candle[]>([])
  const [interval, setInterval] = useState<ChartInterval>('1d')
  const [chartLoading, setChartLoading] = useState(true)
  const [chartError, setChartError] = useState('')

  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY')
  const [qty, setQty] = useState('1')
  const [error, setError] = useState('')
  const [success, setSuccess] = useState('')
  const [loading, setLoading] = useState(false)

  // Live quote poll
  useEffect(() => {
    let cancelled = false
    async function loadQuote() {
      try {
        const q = await fetchQuote(sym)
        if (!cancelled) {
          setStock(q)
          setError('')
        }
      } catch {
        if (!cancelled && !stock) setError('Could not load quote')
      }
    }
    void loadQuote()
    const id = window.setInterval(() => void loadQuote(), QUOTE_POLL_MS)
    return () => {
      cancelled = true
      window.clearInterval(id)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only rebind on symbol
  }, [sym])

  // Candles + refresh
  useEffect(() => {
    let cancelled = false
    async function loadCandles(fast = false) {
      try {
        if (!fast) setChartLoading(true)
        const data = await fetchCandles(sym, interval, { fast })
        if (!cancelled) {
          setCandles(Array.isArray(data) ? data : [])
          setChartError('')
        }
      } catch (err) {
        if (!cancelled) {
          setChartError(err instanceof ApiError ? err.message : 'Could not load chart')
        }
      } finally {
        if (!cancelled) setChartLoading(false)
      }
    }
    void loadCandles(false)
    const id = window.setInterval(() => void loadCandles(true), CANDLE_POLL_MS)
    return () => {
      cancelled = true
      window.clearInterval(id)
    }
  }, [sym, interval])

  async function execute() {
    setError('')
    setSuccess('')
    const quantity = parseInt(qty, 10)
    if (!quantity || quantity < 1) {
      setError('Enter valid quantity')
      return
    }
    setLoading(true)
    try {
      await placePaperTrade(sym, side, quantity)
      setSuccess(`${side} order executed for ${quantity} shares`)
      setTimeout(() => navigate('/app/portfolio'), 1200)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Order failed')
    } finally {
      setLoading(false)
    }
  }

  if (!stock && !error) {
    return (
      <div className="flex justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-lime border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="mx-auto max-w-6xl space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <button
            type="button"
            onClick={() => navigate(-1)}
            className="text-sm text-muted hover:text-white"
          >
            ← Back
          </button>
          <h1 className="mt-2 text-2xl font-bold">{sym}</h1>
          {stock && (
            <p className="text-muted">
              {stock.name} · {formatInrDecimal(Number(stock.ltp))}{' '}
              <span className={Number(stock.changePercent) >= 0 ? 'text-success' : 'text-danger'}>
                {formatPercent(Number(stock.changePercent))}
              </span>
              <span className="ml-2 text-[11px] text-muted">Live · refreshes every 15s</span>
            </p>
          )}
        </div>

        <div className="flex flex-wrap gap-1 rounded-xl border border-white/10 bg-surface/60 p-1">
          {INTERVALS.map((iv) => (
            <button
              key={iv.id}
              type="button"
              onClick={() => setInterval(iv.id)}
              className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition ${
                interval === iv.id
                  ? 'bg-brand-lime text-brand-ink'
                  : 'text-muted hover:text-white'
              }`}
            >
              {iv.label}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-4">
          {chartLoading && !candles.length ? (
            <div className="flex h-[360px] items-center justify-center rounded-2xl border border-white/10 text-muted">
              Loading chart…
            </div>
          ) : chartError && !candles.length ? (
            <div className="flex h-[360px] items-center justify-center rounded-2xl border border-white/10 text-sm text-danger">
              {chartError}
            </div>
          ) : (
            <CandleChart candles={candles} interval={interval} />
          )}

          <div className="glass rounded-2xl p-5">
            <MarketAnalysisPanel candles={candles} quote={stock} />
          </div>
        </div>

        <div className="glass h-fit rounded-2xl p-5 lg:sticky lg:top-4">
          <div className="mb-4 grid grid-cols-2 gap-2">
            {(['BUY', 'SELL'] as const).map((s) => (
              <button
                key={s}
                type="button"
                onClick={() => setSide(s)}
                className={`rounded-xl py-2.5 text-sm font-semibold transition ${
                  side === s
                    ? s === 'BUY'
                      ? 'bg-brand-lime text-brand-ink'
                      : 'bg-danger text-white'
                    : 'border border-white/10 text-muted'
                }`}
              >
                {s}
              </button>
            ))}
          </div>

          <Input
            label="Quantity"
            type="number"
            min={1}
            value={qty}
            onChange={(e) => setQty(e.target.value)}
          />

          {stock && (
            <p className="mt-3 text-sm text-muted">
              Est. value: {formatInrDecimal(Number(stock.ltp) * (parseInt(qty, 10) || 0))}
            </p>
          )}

          {error && <p className="mt-3 text-sm text-danger">{error}</p>}
          {success && <p className="mt-3 text-sm text-success">{success}</p>}

          <Button className="mt-4 w-full" disabled={loading} onClick={execute}>
            {loading ? 'Placing order…' : `Place ${side} order`}
          </Button>

          <p className="mt-3 text-center text-xs text-muted">Practice mode — virtual wallet only</p>
        </div>
      </div>
    </div>
  )
}
