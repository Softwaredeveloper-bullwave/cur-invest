import type { Candle } from '../api/types'

export function smaSeries(closes: number[], period: number): Array<number | null> {
  if (closes.length < period) return closes.map(() => null)
  const out: Array<number | null> = Array(closes.length).fill(null)
  let sum = 0
  for (let i = 0; i < closes.length; i++) {
    sum += closes[i]
    if (i >= period) sum -= closes[i - period]
    if (i >= period - 1) out[i] = sum / period
  }
  return out
}

export function approxRsi(closes: number[], period = 14): number {
  if (closes.length < period + 1) return 50
  let gains = 0
  let losses = 0
  for (let i = closes.length - period; i < closes.length; i++) {
    const diff = closes[i] - closes[i - 1]
    if (diff >= 0) gains += diff
    else losses -= diff
  }
  if (losses === 0) return 70
  const rs = gains / losses
  return Math.round(100 - 100 / (1 + rs))
}

export type TechnicalSnapshot = {
  rsi: number
  macdSignal: 'Buy' | 'Sell' | 'Neutral'
  sma20: number
  sma50: number
  sma200: number
  trend: string
}

export function computeTechnicals(candles: Candle[]): TechnicalSnapshot {
  if (!candles.length) {
    return {
      rsi: 50,
      macdSignal: 'Neutral',
      sma20: 0,
      sma50: 0,
      sma200: 0,
      trend: 'Sideways',
    }
  }
  const closes = candles.map((c) => Number(c.close))
  const avg = (n: number) => {
    const slice = closes.length >= n ? closes.slice(-n) : closes
    return slice.reduce((a, b) => a + b, 0) / slice.length
  }
  const sma20 = avg(20)
  const sma50 = avg(50)
  const sma200 = avg(200)
  const last = closes[closes.length - 1]
  const trend =
    last > sma50
      ? last > sma200
        ? 'Uptrend'
        : 'Bullish'
      : last < sma200
        ? 'Downtrend'
        : 'Bearish'
  const rsi = approxRsi(closes)
  return {
    rsi,
    macdSignal: trend.includes('Up') || trend === 'Bullish' ? 'Buy' : 'Sell',
    sma20,
    sma50,
    sma200,
    trend,
  }
}

export type CandlePattern = {
  name: string
  signal: 'Bullish' | 'Bearish' | 'Neutral'
  atIndex: number
  description: string
}

function body(c: Candle) {
  return Math.abs(Number(c.close) - Number(c.open))
}

function range(c: Candle) {
  return Math.max(Number(c.high) - Number(c.low), 1e-9)
}

function isBullish(c: Candle) {
  return Number(c.close) >= Number(c.open)
}

/** Detect common candlestick patterns on the latest bars. */
export function detectPatterns(candles: Candle[], lookback = 40): CandlePattern[] {
  if (candles.length < 3) return []
  const start = Math.max(1, candles.length - lookback)
  const found: CandlePattern[] = []

  for (let i = start; i < candles.length; i++) {
    const c = candles[i]
    const prev = candles[i - 1]
    const o = Number(c.open)
    const h = Number(c.high)
    const l = Number(c.low)
    const cl = Number(c.close)
    const b = body(c)
    const r = range(c)
    const upper = h - Math.max(o, cl)
    const lower = Math.min(o, cl) - l

    // Doji
    if (b / r < 0.1) {
      found.push({
        name: 'Doji',
        signal: 'Neutral',
        atIndex: i,
        description: 'Indecision — open and close nearly equal',
      })
    }

    // Hammer (bullish reversal after decline)
    if (lower > b * 2 && upper < b * 0.5 && b / r < 0.35) {
      found.push({
        name: 'Hammer',
        signal: 'Bullish',
        atIndex: i,
        description: 'Long lower wick — potential bounce',
      })
    }

    // Shooting star
    if (upper > b * 2 && lower < b * 0.5 && b / r < 0.35) {
      found.push({
        name: 'Shooting Star',
        signal: 'Bearish',
        atIndex: i,
        description: 'Long upper wick — potential rejection',
      })
    }

    // Bullish engulfing
    if (
      !isBullish(prev) &&
      isBullish(c) &&
      Number(c.open) <= Number(prev.close) &&
      Number(c.close) >= Number(prev.open)
    ) {
      found.push({
        name: 'Bullish Engulfing',
        signal: 'Bullish',
        atIndex: i,
        description: 'Green candle engulfs prior red body',
      })
    }

    // Bearish engulfing
    if (
      isBullish(prev) &&
      !isBullish(c) &&
      Number(c.open) >= Number(prev.close) &&
      Number(c.close) <= Number(prev.open)
    ) {
      found.push({
        name: 'Bearish Engulfing',
        signal: 'Bearish',
        atIndex: i,
        description: 'Red candle engulfs prior green body',
      })
    }

    // Morning star (3-candle)
    if (i >= 2) {
      const a = candles[i - 2]
      const mid = candles[i - 1]
      if (
        !isBullish(a) &&
        body(mid) / range(mid) < 0.3 &&
        isBullish(c) &&
        Number(c.close) > (Number(a.open) + Number(a.close)) / 2
      ) {
        found.push({
          name: 'Morning Star',
          signal: 'Bullish',
          atIndex: i,
          description: '3-candle bullish reversal pattern',
        })
      }
    }
  }

  // Keep latest unique pattern names (most recent wins)
  const byName = new Map<string, CandlePattern>()
  for (const p of found) byName.set(p.name, p)
  return [...byName.values()].sort((a, b) => b.atIndex - a.atIndex).slice(0, 6)
}
