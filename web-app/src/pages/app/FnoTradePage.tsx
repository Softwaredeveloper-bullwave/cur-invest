import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import { Button } from '../../components/ui/Button'
import { Input } from '../../components/ui/Input'
import { CandleChart } from '../../components/charts/CandleChart'
import { PayoffChart } from '../../components/fno/PayoffChart'
import {
  ApiError,
  fetchCandles,
  fetchOptionChain,
  fetchOptionHoldings,
  fetchOptionTrades,
  fetchPracticeWallet,
  placeOptionOrder,
} from '../../api/client'
import type {
  Candle,
  OptionChain,
  OptionContract,
  OptionHolding,
  OptionTrade,
} from '../../api/types'
import {
  FNO_INDICES,
  fnoLotSize,
  futuresMarginInr,
  optionPremiumInr,
} from '../../lib/fno'
import {
  daysUntil,
  holdingUnrealizedPnl,
  livePremiumFromChain,
  netPnlForHoldings,
  payoffPoints,
  syntheticOptionCandles,
} from '../../lib/fnoPnl'
import { formatInr, formatInrDecimal } from '../../lib/format'

const CHAIN_POLL_MS = 12_000
const BOOK_POLL_MS = 20_000

type StrikeRow = {
  strike: number
  ce?: OptionContract
  pe?: OptionContract
}

type Ticket = {
  optionType: 'CE' | 'PE' | 'FU'
  strike: number
  premium: number
  label: string
}

function buildStrikeRows(contracts: OptionContract[]): StrikeRow[] {
  const map = new Map<number, StrikeRow>()
  for (const c of contracts) {
    const strike = Number(c.strike)
    const row = map.get(strike) ?? { strike }
    if (c.type === 'CE') row.ce = c
    else row.pe = c
    map.set(strike, row)
  }
  return [...map.values()].sort((a, b) => a.strike - b.strike)
}

export function FnoTradePage() {
  const { symbol = 'NIFTY' } = useParams()
  const sym = symbol.toUpperCase()
  const [searchParams, setSearchParams] = useSearchParams()
  const tab = searchParams.get('tab') === 'futures' ? 'futures' : 'options'
  const navigate = useNavigate()

  const [chain, setChain] = useState<OptionChain | null>(null)
  const [expiry, setExpiry] = useState('')
  const [candles, setCandles] = useState<Candle[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [ticket, setTicket] = useState<Ticket | null>(null)
  const [side, setSide] = useState<'BUY' | 'SELL'>('BUY')
  const [lots, setLots] = useState('1')
  const [orderMsg, setOrderMsg] = useState('')
  const [orderErr, setOrderErr] = useState('')
  const [placing, setPlacing] = useState(false)
  const [strikeFilter, setStrikeFilter] = useState<'all' | 'atm'>('atm')
  const [wallet, setWallet] = useState(0)
  const [holdings, setHoldings] = useState<OptionHolding[]>([])
  const [trades, setTrades] = useState<OptionTrade[]>([])
  const [deskOpen, setDeskOpen] = useState(false)

  const meta = FNO_INDICES.find((i) => i.symbol === sym)
  const lotSize = fnoLotSize(sym)
  const selectedExpiry = expiry || chain?.selectedExpiry || ''

  const refreshBook = useCallback(async () => {
    try {
      const [w, h, t] = await Promise.all([
        fetchPracticeWallet(),
        fetchOptionHoldings(),
        fetchOptionTrades(),
      ])
      setWallet(Number(w.balance))
      setHoldings((h.holdings ?? []).filter((x) => x.underlying.toUpperCase() === sym))
      setTrades((t.trades ?? []).filter((x) => x.underlying.toUpperCase() === sym).slice(0, 12))
    } catch {
      // book is secondary
    }
  }, [sym])

  useEffect(() => {
    void refreshBook()
    const id = window.setInterval(() => void refreshBook(), BOOK_POLL_MS)
    return () => window.clearInterval(id)
  }, [refreshBook])

  useEffect(() => {
    let cancelled = false
    async function load(fast = false) {
      try {
        const data = await fetchOptionChain(sym, {
          expiry: expiry || undefined,
          fast,
        })
        if (cancelled) return
        setChain(data)
        if (!expiry && data.selectedExpiry) setExpiry(data.selectedExpiry)
        setError('')
        // Keep ticket premium fresh while open
        setTicket((prev) => {
          if (!prev || prev.optionType === 'FU') {
            if (prev?.optionType === 'FU') {
              return { ...prev, premium: Number(data.underlyingValue) }
            }
            return prev
          }
          const ltp = livePremiumFromChain(
            data.contracts,
            prev.strike,
            prev.optionType,
            Number(data.underlyingValue),
          )
          return ltp ? { ...prev, premium: ltp } : prev
        })
      } catch (err) {
        if (!cancelled) {
          setError(err instanceof ApiError ? err.message : 'Could not load option chain')
        }
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    void load(false)
    const id = window.setInterval(() => void load(true), CHAIN_POLL_MS)
    return () => {
      cancelled = true
      window.clearInterval(id)
    }
  }, [sym, expiry])

  useEffect(() => {
    let cancelled = false
    void fetchCandles(sym, '5m', { fast: true })
      .then((c) => {
        if (!cancelled) setCandles(Array.isArray(c) ? c : [])
      })
      .catch(() => {
        if (!cancelled) setCandles([])
      })
    return () => {
      cancelled = true
    }
  }, [sym])

  const rows = useMemo(() => buildStrikeRows(chain?.contracts ?? []), [chain])
  const spot = Number(chain?.underlyingValue ?? 0)

  const atmStrike = useMemo(() => {
    if (!rows.length || !spot) return 0
    return rows.reduce((best, row) =>
      Math.abs(row.strike - spot) < Math.abs(best.strike - spot) ? row : best,
    ).strike
  }, [rows, spot])

  const visibleRows = useMemo(() => {
    if (strikeFilter === 'all' || !atmStrike) return rows
    const idx = rows.findIndex((r) => r.strike === atmStrike)
    if (idx < 0) return rows
    return rows.slice(Math.max(0, idx - 8), Math.min(rows.length, idx + 9))
  }, [rows, strikeFilter, atmStrike])

  const markFor = useCallback(
    (h: OptionHolding) =>
      livePremiumFromChain(
        chain?.contracts ?? [],
        Number(h.strike),
        h.optionType as 'CE' | 'PE' | 'FU',
        spot,
      ) || Number(h.avgPremium),
    [chain, spot],
  )

  const bookStats = useMemo(
    () => netPnlForHoldings(holdings, markFor),
    [holdings, markFor],
  )

  const activeHolding = useMemo(() => {
    if (!ticket) return null
    return (
      holdings.find(
        (h) =>
          h.optionType === ticket.optionType &&
          (ticket.optionType === 'FU' || Number(h.strike) === ticket.strike) &&
          h.expiry === selectedExpiry,
      ) ?? null
    )
  }, [holdings, ticket, selectedExpiry])

  const activeMark = ticket
    ? livePremiumFromChain(
        chain?.contracts ?? [],
        ticket.strike,
        ticket.optionType,
        spot,
      ) || ticket.premium
    : 0

  const activeUnrealized = activeHolding
    ? holdingUnrealizedPnl(activeHolding, activeMark)
    : 0

  const chartCandles = useMemo(() => {
    if (!ticket || ticket.optionType === 'FU') return candles
    if (!candles.length) return []
    return syntheticOptionCandles(
      candles,
      ticket.strike,
      ticket.optionType,
      daysUntil(selectedExpiry),
    )
  }, [ticket, candles, selectedExpiry])

  const payoff = useMemo(() => {
    if (!ticket || !spot) return []
    return payoffPoints(
      ticket.strike,
      ticket.optionType,
      ticket.premium,
      lotSize,
      spot,
    )
  }, [ticket, spot, lotSize])

  function openOption(type: 'CE' | 'PE', contract?: OptionContract) {
    if (!contract || !chain) return
    setTicket({
      optionType: type,
      strike: Number(contract.strike),
      premium: Number(contract.ltp),
      label: `${sym} ${Number(contract.strike)} ${type}`,
    })
    setOrderMsg('')
    setOrderErr('')
    setSide('BUY')
    setDeskOpen(true)
    setSearchParams({ tab: 'options' })
  }

  function openFutures() {
    if (!chain || !spot) return
    setTicket({
      optionType: 'FU',
      strike: 0,
      premium: spot,
      label: `${sym} FUT`,
    })
    setOrderMsg('')
    setOrderErr('')
    setSide('BUY')
    setDeskOpen(true)
    setSearchParams({ tab: 'futures' })
  }

  function openStrikeRow(row: StrikeRow, prefer: 'CE' | 'PE' = 'CE') {
    if (prefer === 'CE' && row.ce) openOption('CE', row.ce)
    else if (row.pe) openOption('PE', row.pe)
    else if (row.ce) openOption('CE', row.ce)
  }

  async function placeOrder() {
    if (!ticket || !chain) return
    const quantity = parseInt(lots, 10)
    if (!quantity || quantity < 1) {
      setOrderErr('Enter lots ≥ 1')
      return
    }
    setPlacing(true)
    setOrderErr('')
    setOrderMsg('')
    try {
      const res = await placeOptionOrder({
        underlying: sym,
        strike: ticket.optionType === 'FU' ? 0 : ticket.strike,
        optionType: ticket.optionType,
        expiry: selectedExpiry,
        side,
        quantity,
        premium: ticket.optionType === 'FU' ? spot || ticket.premium : ticket.premium,
      })
      setOrderMsg(
        `${side} filled · ${formatInrDecimal(Number(res.amountInr))} · wallet ${formatInrDecimal(Number(res.practiceWalletBalance ?? 0))}`,
      )
      if (res.practiceWalletBalance != null) setWallet(Number(res.practiceWalletBalance))
      await refreshBook()
    } catch (err) {
      setOrderErr(err instanceof ApiError ? err.message : 'Order failed')
    } finally {
      setPlacing(false)
    }
  }

  const estValue = ticket
    ? ticket.optionType === 'FU'
      ? futuresMarginInr(spot || ticket.premium, parseInt(lots, 10) || 0, lotSize)
      : optionPremiumInr(ticket.premium, parseInt(lots, 10) || 0, lotSize)
    : 0

  if (loading && !chain) {
    return (
      <div className="flex justify-center py-20">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-lime border-t-transparent" />
      </div>
    )
  }

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <button
            type="button"
            onClick={() => navigate('/app/fno')}
            className="text-sm text-muted hover:text-white"
          >
            ← All underlyings
          </button>
          <h1 className="mt-1 text-2xl font-bold">{sym}</h1>
          <p className="text-sm text-muted">
            {meta?.label ?? 'Stock F&O'} · Lot {lotSize}
            {chain?.provider ? ` · ${chain.provider}` : ''}
          </p>
        </div>
        <div className="text-right">
          <div className="text-xs uppercase tracking-wide text-muted">Spot</div>
          <div className="text-2xl font-bold text-brand-lime">
            {spot ? formatInrDecimal(spot) : '—'}
          </div>
          <div className="text-[11px] text-muted">Live chain · ~12s</div>
        </div>
      </div>

      {/* Book summary */}
      <div className="grid gap-3 sm:grid-cols-4">
        <div className="glass rounded-xl p-3">
          <div className="text-[11px] text-muted">Practice wallet</div>
          <div className="text-lg font-bold text-brand-lime">{formatInr(wallet)}</div>
        </div>
        <div className="glass rounded-xl p-3">
          <div className="text-[11px] text-muted">Open positions</div>
          <div className="text-lg font-bold">{holdings.length}</div>
        </div>
        <div className="glass rounded-xl p-3">
          <div className="text-[11px] text-muted">Capital in F&O</div>
          <div className="text-lg font-bold">{formatInrDecimal(bookStats.invested)}</div>
        </div>
        <div className="glass rounded-xl p-3">
          <div className="text-[11px] text-muted">Net unrealized P&amp;L</div>
          <div
            className={`text-lg font-bold ${
              bookStats.pnl >= 0 ? 'text-success' : 'text-danger'
            }`}
          >
            {formatInrDecimal(bookStats.pnl)}
          </div>
        </div>
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          onClick={() => setSearchParams({ tab: 'options' })}
          className={`rounded-xl px-4 py-2 text-sm font-semibold ${
            tab === 'options' ? 'bg-brand-lime text-brand-ink' : 'border border-white/10 text-muted'
          }`}
        >
          Options
        </button>
        <button
          type="button"
          onClick={() => {
            setSearchParams({ tab: 'futures' })
            openFutures()
          }}
          className={`rounded-xl px-4 py-2 text-sm font-semibold ${
            tab === 'futures' ? 'bg-brand-lime text-brand-ink' : 'border border-white/10 text-muted'
          }`}
        >
          Futures
        </button>
        <Link
          to={`/app/trade/${sym}`}
          className="rounded-xl border border-white/10 px-4 py-2 text-sm text-muted hover:text-white"
        >
          Equity chart
        </Link>
      </div>

      {error && <p className="text-sm text-danger">{error}</p>}

      <div className={`grid gap-5 ${deskOpen && ticket ? 'xl:grid-cols-[1.15fr_0.85fr]' : ''}`}>
        <div className="space-y-4 min-w-0">
          {tab === 'futures' ? (
            <div className="glass rounded-2xl p-5">
              <h2 className="font-semibold">{sym} Index Futures</h2>
              <p className="mt-1 text-sm text-muted">
                Click trade to open chart + BUY/SELL. Margin ≈ 12% (
                {formatInrDecimal(futuresMarginInr(spot, 1, lotSize))} / lot).
              </p>
              <div className="mt-4 grid gap-3 sm:grid-cols-3">
                <div className="rounded-xl border border-white/10 bg-surface/50 p-3">
                  <div className="text-xs text-muted">Futures price</div>
                  <div className="text-lg font-bold">{formatInrDecimal(spot)}</div>
                </div>
                <div className="rounded-xl border border-white/10 bg-surface/50 p-3">
                  <div className="text-xs text-muted">Expiry</div>
                  <div className="text-lg font-bold">{selectedExpiry || '—'}</div>
                </div>
                <div className="rounded-xl border border-white/10 bg-surface/50 p-3">
                  <div className="text-xs text-muted">Lot size</div>
                  <div className="text-lg font-bold">{lotSize}</div>
                </div>
              </div>
              <Button className="mt-4" onClick={openFutures}>
                Trade futures — chart &amp; ticket
              </Button>
            </div>
          ) : (
            <>
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-xs text-muted">Expiry</span>
                {(chain?.expiryDates ?? []).map((d) => (
                  <button
                    key={d}
                    type="button"
                    onClick={() => setExpiry(d)}
                    className={`rounded-lg px-3 py-1.5 text-xs font-semibold ${
                      selectedExpiry === d
                        ? 'bg-brand-lime text-brand-ink'
                        : 'border border-white/10 text-muted'
                    }`}
                  >
                    {d}
                  </button>
                ))}
                <div className="ml-auto flex gap-1 rounded-lg border border-white/10 p-0.5">
                  <button
                    type="button"
                    onClick={() => setStrikeFilter('atm')}
                    className={`rounded-md px-2 py-1 text-[11px] ${
                      strikeFilter === 'atm' ? 'bg-white/10 text-white' : 'text-muted'
                    }`}
                  >
                    Near ATM
                  </button>
                  <button
                    type="button"
                    onClick={() => setStrikeFilter('all')}
                    className={`rounded-md px-2 py-1 text-[11px] ${
                      strikeFilter === 'all' ? 'bg-white/10 text-white' : 'text-muted'
                    }`}
                  >
                    All strikes
                  </button>
                </div>
              </div>

              <p className="text-xs text-muted">
                Tap CE / PE LTP (or Buy buttons) to open chart, call/put ticket, and live P&amp;L.
              </p>

              <div className="overflow-x-auto rounded-2xl border border-white/10">
                <table className="min-w-full text-sm">
                  <thead className="bg-surface text-xs uppercase tracking-wide text-muted">
                    <tr>
                      <th className="px-2 py-2 text-left">OI</th>
                      <th className="px-2 py-2 text-left">CE LTP</th>
                      <th className="px-2 py-2 text-left">Chg</th>
                      <th className="px-2 py-2 text-center">Trade</th>
                      <th className="px-2 py-2 text-center">Strike</th>
                      <th className="px-2 py-2 text-center">Trade</th>
                      <th className="px-2 py-2 text-right">Chg</th>
                      <th className="px-2 py-2 text-right">PE LTP</th>
                      <th className="px-2 py-2 text-right">OI</th>
                    </tr>
                  </thead>
                  <tbody>
                    {visibleRows.map((row) => {
                      const isAtm = row.strike === atmStrike
                      const selected =
                        ticket &&
                        ticket.optionType !== 'FU' &&
                        ticket.strike === row.strike
                      return (
                        <tr
                          key={row.strike}
                          className={`border-t border-white/5 cursor-pointer ${
                            selected
                              ? 'bg-brand-lime/20'
                              : isAtm
                                ? 'bg-brand-lime/10'
                                : 'hover:bg-white/[0.04]'
                          }`}
                          onClick={() => openStrikeRow(row)}
                        >
                          <td className="px-2 py-2 text-xs text-muted">
                            {row.ce ? (row.ce.oi / 1000).toFixed(0) + 'k' : '—'}
                          </td>
                          <td className="px-2 py-2">
                            <button
                              type="button"
                              className="font-semibold text-success hover:underline"
                              onClick={(e) => {
                                e.stopPropagation()
                                openOption('CE', row.ce)
                              }}
                            >
                              {row.ce ? formatInrDecimal(Number(row.ce.ltp)) : '—'}
                            </button>
                          </td>
                          <td
                            className={`px-2 py-2 text-xs ${
                              Number(row.ce?.change ?? 0) >= 0 ? 'text-success' : 'text-danger'
                            }`}
                          >
                            {row.ce
                              ? `${Number(row.ce.change) >= 0 ? '+' : ''}${Number(row.ce.change).toFixed(2)}`
                              : '—'}
                          </td>
                          <td className="px-1 py-2 text-center">
                            <button
                              type="button"
                              disabled={!row.ce}
                              onClick={(e) => {
                                e.stopPropagation()
                                openOption('CE', row.ce)
                              }}
                              className="rounded-md bg-success px-2 py-1 text-[10px] font-bold text-brand-ink disabled:opacity-30"
                            >
                              Buy CE
                            </button>
                          </td>
                          <td className="px-2 py-2 text-center font-bold">
                            {row.strike}
                            {isAtm ? (
                              <span className="ml-1 text-[10px] text-brand-lime">ATM</span>
                            ) : null}
                          </td>
                          <td className="px-1 py-2 text-center">
                            <button
                              type="button"
                              disabled={!row.pe}
                              onClick={(e) => {
                                e.stopPropagation()
                                openOption('PE', row.pe)
                              }}
                              className="rounded-md bg-danger px-2 py-1 text-[10px] font-bold text-white disabled:opacity-30"
                            >
                              Buy PE
                            </button>
                          </td>
                          <td
                            className={`px-2 py-2 text-right text-xs ${
                              Number(row.pe?.change ?? 0) >= 0 ? 'text-success' : 'text-danger'
                            }`}
                          >
                            {row.pe
                              ? `${Number(row.pe.change) >= 0 ? '+' : ''}${Number(row.pe.change).toFixed(2)}`
                              : '—'}
                          </td>
                          <td className="px-2 py-2 text-right">
                            <button
                              type="button"
                              className="font-semibold text-danger hover:underline"
                              onClick={(e) => {
                                e.stopPropagation()
                                openOption('PE', row.pe)
                              }}
                            >
                              {row.pe ? formatInrDecimal(Number(row.pe.ltp)) : '—'}
                            </button>
                          </td>
                          <td className="px-2 py-2 text-right text-xs text-muted">
                            {row.pe ? (row.pe.oi / 1000).toFixed(0) + 'k' : '—'}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
                {!visibleRows.length && (
                  <p className="p-6 text-center text-sm text-muted">No contracts for this expiry.</p>
                )}
              </div>
            </>
          )}

          {/* Positions for this underlying */}
          <div className="glass rounded-2xl p-4">
            <div className="mb-3 flex items-center justify-between">
              <h3 className="font-semibold">Open {sym} positions</h3>
              <span
                className={`text-sm font-semibold ${
                  bookStats.pnl >= 0 ? 'text-success' : 'text-danger'
                }`}
              >
                Net P&amp;L {formatInrDecimal(bookStats.pnl)}
              </span>
            </div>
            {holdings.length === 0 ? (
              <p className="text-sm text-muted">No open lots — pick a strike to trade.</p>
            ) : (
              <div className="space-y-2">
                {holdings.map((h) => {
                  const mark = markFor(h)
                  const pnl = holdingUnrealizedPnl(h, mark)
                  return (
                    <button
                      key={`${h.strike}-${h.optionType}-${h.expiry}`}
                      type="button"
                      className="flex w-full items-center justify-between gap-3 rounded-xl bg-midnight/50 px-3 py-2 text-left text-sm hover:bg-white/5"
                      onClick={() => {
                        if (h.optionType === 'FU') openFutures()
                        else {
                          const contract = (chain?.contracts ?? []).find(
                            (c) =>
                              Number(c.strike) === Number(h.strike) &&
                              c.type === h.optionType,
                          )
                          if (contract) openOption(h.optionType as 'CE' | 'PE', contract)
                        }
                      }}
                    >
                      <span>
                        {h.contractLabel} · {h.quantity} lot
                        {h.quantity === 1 ? '' : 's'}
                        <span className="mt-0.5 block text-[11px] text-muted">
                          Avg {formatInrDecimal(Number(h.avgPremium))} · LTP{' '}
                          {formatInrDecimal(mark)}
                        </span>
                      </span>
                      <span className={pnl >= 0 ? 'text-success font-semibold' : 'text-danger font-semibold'}>
                        {formatInrDecimal(pnl)}
                      </span>
                    </button>
                  )
                })}
              </div>
            )}
          </div>
        </div>

        {/* Trade desk panel */}
        {deskOpen && ticket && (
          <aside className="glass h-fit space-y-4 rounded-2xl border border-brand-lime/25 p-4 xl:sticky xl:top-4">
            <div className="flex items-start justify-between gap-2">
              <div>
                <div className="text-[11px] uppercase tracking-wide text-muted">Trade desk</div>
                <div className="text-lg font-bold">{ticket.label}</div>
                <div className="text-sm text-muted">
                  LTP {formatInrDecimal(activeMark)}
                  {ticket.optionType !== 'FU' ? ` · Strike ${ticket.strike}` : ` · Spot ${formatInrDecimal(spot)}`}
                </div>
              </div>
              <button
                type="button"
                className="text-xs text-muted hover:text-white"
                onClick={() => {
                  setDeskOpen(false)
                  setTicket(null)
                }}
              >
                Close
              </button>
            </div>

            {/* CE / PE switch when on options */}
            {ticket.optionType !== 'FU' && (
              <div className="grid grid-cols-2 gap-2">
                {(['CE', 'PE'] as const).map((ot) => {
                  const row = rows.find((r) => r.strike === ticket.strike)
                  const c = ot === 'CE' ? row?.ce : row?.pe
                  return (
                    <button
                      key={ot}
                      type="button"
                      disabled={!c}
                      onClick={() => openOption(ot, c)}
                      className={`rounded-xl py-2 text-sm font-semibold ${
                        ticket.optionType === ot
                          ? ot === 'CE'
                            ? 'bg-success text-brand-ink'
                            : 'bg-danger text-white'
                          : 'border border-white/10 text-muted'
                      }`}
                    >
                      {ot} {c ? formatInrDecimal(Number(c.ltp)) : ''}
                    </button>
                  )
                })}
              </div>
            )}

            <div>
              <div className="mb-1 text-xs text-muted">
                {ticket.optionType === 'FU' ? 'Futures / spot chart' : 'Premium chart (model)'}
              </div>
              {chartCandles.length > 0 ? (
                <CandleChart
                  candles={chartCandles}
                  interval="5m"
                  height={200}
                />
              ) : (
                <div className="flex h-[200px] items-center justify-center rounded-xl border border-white/10 text-sm text-muted">
                  Loading chart…
                </div>
              )}
            </div>

            <div>
              <div className="mb-1 text-xs text-muted">Expiry payoff (1 lot long)</div>
              <div className="rounded-xl border border-white/10 bg-surface/40 p-2">
                <PayoffChart points={payoff} />
              </div>
            </div>

            {activeHolding && (
              <div className="rounded-xl border border-white/10 bg-surface/50 p-3 text-sm">
                <div className="flex justify-between">
                  <span className="text-muted">Your position</span>
                  <span className="font-semibold">
                    {activeHolding.quantity} lot{activeHolding.quantity === 1 ? '' : 's'}
                  </span>
                </div>
                <div className="mt-1 flex justify-between">
                  <span className="text-muted">Unrealized P&amp;L</span>
                  <span
                    className={`font-bold ${
                      activeUnrealized >= 0 ? 'text-success' : 'text-danger'
                    }`}
                  >
                    {formatInrDecimal(activeUnrealized)}
                  </span>
                </div>
              </div>
            )}

            <div className="grid grid-cols-2 gap-2">
              {(['BUY', 'SELL'] as const).map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setSide(s)}
                  className={`rounded-xl py-2.5 text-sm font-semibold ${
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
              label="Lots"
              type="number"
              min={1}
              value={lots}
              onChange={(e) => setLots(e.target.value)}
            />

            <p className="text-xs text-muted">
              Est. {ticket.optionType === 'FU' ? 'margin' : 'premium'}:{' '}
              <span className="font-semibold text-white">{formatInrDecimal(estValue)}</span>
              {' · '}Wallet {formatInr(wallet)}
            </p>

            <Button className="w-full" disabled={placing} onClick={() => void placeOrder()}>
              {placing ? 'Placing…' : `${side} ${ticket.optionType}`}
            </Button>
            {orderErr && <p className="text-sm text-danger">{orderErr}</p>}
            {orderMsg && <p className="text-sm text-success">{orderMsg}</p>}
            <p className="text-[11px] text-muted">
              Paper mode — SELL closes lots you hold. P&amp;L marks to live chain LTP.
            </p>

            {trades.length > 0 && (
              <div>
                <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">
                  Recent {sym} orders
                </div>
                <ul className="max-h-40 space-y-1 overflow-y-auto text-xs">
                  {trades.map((t) => (
                    <li
                      key={t.id}
                      className="flex justify-between gap-2 rounded-lg bg-midnight/40 px-2 py-1.5"
                    >
                      <span>
                        <span className={t.side === 'BUY' ? 'text-success' : 'text-danger'}>
                          {t.side}
                        </span>{' '}
                        {t.optionType} {t.optionType === 'FU' ? '' : t.strike} ×{t.quantity}
                      </span>
                      <span className="text-muted">{formatInrDecimal(Number(t.amountInr))}</span>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </aside>
        )}
      </div>
    </div>
  )
}
