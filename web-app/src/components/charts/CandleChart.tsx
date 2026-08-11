import { useEffect, useRef } from 'react'
import {
  CandlestickSeries,
  ColorType,
  CrosshairMode,
  HistogramSeries,
  LineSeries,
  createChart,
  type IChartApi,
  type ISeriesApi,
  type UTCTimestamp,
} from 'lightweight-charts'
import type { Candle, ChartInterval } from '../../api/types'
import { smaSeries } from '../../lib/indicators'

function isIntraday(interval: ChartInterval) {
  return interval === '1m' || interval === '5m' || interval === '30m' || interval === '1h'
}

function toChartTime(iso: string, intraday: boolean): UTCTimestamp | string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return Math.floor(Date.now() / 1000) as UTCTimestamp
  if (intraday) return Math.floor(d.getTime() / 1000) as UTCTimestamp
  // Daily: business day string avoids timezone skew
  return d.toISOString().slice(0, 10)
}

type Props = {
  candles: Candle[]
  interval: ChartInterval
  height?: number
}

export function CandleChart({ candles, interval, height = 360 }: Props) {
  const hostRef = useRef<HTMLDivElement>(null)
  const chartRef = useRef<IChartApi | null>(null)

  useEffect(() => {
    const el = hostRef.current
    if (!el) return

    const chart = createChart(el, {
      height,
      layout: {
        background: { type: ColorType.Solid, color: 'transparent' },
        textColor: '#94a3b8',
        fontFamily: 'Inter, system-ui, sans-serif',
      },
      grid: {
        vertLines: { color: 'rgba(255,255,255,0.04)' },
        horzLines: { color: 'rgba(255,255,255,0.04)' },
      },
      crosshair: { mode: CrosshairMode.Normal },
      rightPriceScale: { borderColor: 'rgba(255,255,255,0.08)' },
      timeScale: {
        borderColor: 'rgba(255,255,255,0.08)',
        timeVisible: isIntraday(interval),
        secondsVisible: false,
      },
    })
    chartRef.current = chart

    const candleSeries = chart.addSeries(CandlestickSeries, {
      upColor: '#22c55e',
      downColor: '#ef4444',
      borderUpColor: '#22c55e',
      borderDownColor: '#ef4444',
      wickUpColor: '#22c55e',
      wickDownColor: '#ef4444',
    }) as ISeriesApi<'Candlestick'>

    const volumeSeries = chart.addSeries(HistogramSeries, {
      priceFormat: { type: 'volume' },
      priceScaleId: 'vol',
    }) as ISeriesApi<'Histogram'>
    chart.priceScale('vol').applyOptions({
      scaleMargins: { top: 0.78, bottom: 0 },
    })

    const sma20Series = chart.addSeries(LineSeries, {
      color: '#38bdf8',
      lineWidth: 2,
      priceLineVisible: false,
      lastValueVisible: false,
      crosshairMarkerVisible: false,
    }) as ISeriesApi<'Line'>

    const sma50Series = chart.addSeries(LineSeries, {
      color: '#f59e0b',
      lineWidth: 2,
      priceLineVisible: false,
      lastValueVisible: false,
      crosshairMarkerVisible: false,
    }) as ISeriesApi<'Line'>

    const intraday = isIntraday(interval)
    const byTime = new Map<string | number, Candle>()
    for (const c of candles) {
      byTime.set(toChartTime(c.time, intraday), c)
    }
    const ordered = [...byTime.entries()].sort((a, b) => {
      const ta = typeof a[0] === 'number' ? a[0] : Date.parse(String(a[0]))
      const tb = typeof b[0] === 'number' ? b[0] : Date.parse(String(b[0]))
      return ta - tb
    })

    const ohlc = ordered.map(([time, c]) => ({
      time: time as UTCTimestamp | string,
      open: Number(c.open),
      high: Number(c.high),
      low: Number(c.low),
      close: Number(c.close),
    }))

    candleSeries.setData(ohlc as never)

    volumeSeries.setData(
      ordered.map(([time, c]) => ({
        time: time as UTCTimestamp | string,
        value: Number(c.volume) || 0,
        color:
          Number(c.close) >= Number(c.open)
            ? 'rgba(34,197,94,0.35)'
            : 'rgba(239,68,68,0.35)',
      })) as never,
    )

    const closes = ordered.map(([, c]) => Number(c.close))
    const s20 = smaSeries(closes, 20)
    const s50 = smaSeries(closes, 50)
    sma20Series.setData(
      ordered
        .map(([time], i) =>
          s20[i] == null ? null : { time: time as UTCTimestamp | string, value: s20[i]! },
        )
        .filter(Boolean) as never,
    )
    sma50Series.setData(
      ordered
        .map(([time], i) =>
          s50[i] == null ? null : { time: time as UTCTimestamp | string, value: s50[i]! },
        )
        .filter(Boolean) as never,
    )

    chart.timeScale().fitContent()

    const ro = new ResizeObserver(() => {
      if (!hostRef.current) return
      chart.applyOptions({ width: hostRef.current.clientWidth, height })
    })
    ro.observe(el)

    return () => {
      ro.disconnect()
      chart.remove()
      chartRef.current = null
    }
  }, [candles, interval, height])

  if (!candles.length) {
    return (
      <div
        className="flex items-center justify-center rounded-2xl border border-white/10 bg-surface/40 text-sm text-muted"
        style={{ height }}
      >
        No candle data for this interval
      </div>
    )
  }

  return <div ref={hostRef} className="w-full overflow-hidden rounded-2xl border border-white/10 bg-surface/40" />
}
