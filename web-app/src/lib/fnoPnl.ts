import type { Candle, OptionContract, OptionHolding } from '../api/types'
import { FUTURES_MARGIN_PCT } from './fno'

export function livePremiumFromChain(
  contracts: OptionContract[],
  strike: number,
  optionType: 'CE' | 'PE' | 'FU',
  spot: number,
): number {
  if (optionType === 'FU') return spot
  const hit = contracts.find(
    (c) => Number(c.strike) === strike && c.type === optionType,
  )
  return hit ? Number(hit.ltp) : 0
}

/** Unrealized P&L for a holding marked to live premium/spot. */
export function holdingUnrealizedPnl(
  holding: OptionHolding,
  markPremium: number,
): number {
  const qty = Number(holding.quantity)
  const lot = Number(holding.lotSize) || 1
  const avg = Number(holding.avgPremium)
  if (holding.optionType === 'FU') {
    // Futures: full point PnL (margin is separate capital)
    return (markPremium - avg) * qty * lot
  }
  return (markPremium - avg) * qty * lot
}

export function holdingInvested(holding: OptionHolding): number {
  const qty = Number(holding.quantity)
  const lot = Number(holding.lotSize) || 1
  const avg = Number(holding.avgPremium)
  if (holding.optionType === 'FU') {
    return avg * qty * lot * FUTURES_MARGIN_PCT
  }
  return avg * qty * lot
}

export function netPnlForHoldings(
  holdings: OptionHolding[],
  markFor: (h: OptionHolding) => number,
): { invested: number; mtm: number; pnl: number } {
  let invested = 0
  let pnl = 0
  for (const h of holdings) {
    const mark = markFor(h)
    invested += holdingInvested(h)
    pnl += holdingUnrealizedPnl(h, mark)
  }
  return { invested, mtm: invested + pnl, pnl }
}

/** Build a synthetic option premium series from underlying candles for the chart. */
export function syntheticOptionCandles(
  underlying: Candle[],
  strike: number,
  optionType: 'CE' | 'PE',
  daysToExpiry = 7,
): Candle[] {
  const vol = 0.018
  return underlying.map((c) => {
    const spot = Number(c.close)
    const moneyness = Math.abs(spot - strike) / Math.max(spot, 1)
    const intrinsic =
      optionType === 'CE' ? Math.max(0, spot - strike) : Math.max(0, strike - spot)
    const timeVal =
      spot * vol * Math.sqrt(Math.max(daysToExpiry, 1) / 365) * Math.exp(-moneyness * 4)
    const mid = Math.max(intrinsic + timeVal, 0.05)
    const wobble = mid * 0.02
    return {
      time: c.time,
      open: Math.max(mid - wobble * 0.3, 0.05),
      high: mid + wobble,
      low: Math.max(mid - wobble, 0.05),
      close: mid,
      volume: Number(c.volume) || 0,
    }
  })
}

export function daysUntil(expiryIso: string): number {
  const end = Date.parse(expiryIso)
  if (Number.isNaN(end)) return 7
  return Math.max(1, Math.ceil((end - Date.now()) / (24 * 3600 * 1000)))
}

/** Simple option payoff at expiry for 1 lot (premium paid). */
export function payoffPoints(
  strike: number,
  optionType: 'CE' | 'PE' | 'FU',
  premium: number,
  lotSize: number,
  spotCenter: number,
): { spot: number; pnl: number }[] {
  const span = Math.max(spotCenter * 0.06, 200)
  const points: { spot: number; pnl: number }[] = []
  for (let i = 0; i <= 40; i++) {
    const s = spotCenter - span + (span * 2 * i) / 40
    let pnl = 0
    if (optionType === 'FU') {
      pnl = (s - premium) * lotSize
    } else if (optionType === 'CE') {
      pnl = (Math.max(0, s - strike) - premium) * lotSize
    } else {
      pnl = (Math.max(0, strike - s) - premium) * lotSize
    }
    points.push({ spot: s, pnl })
  }
  return points
}
