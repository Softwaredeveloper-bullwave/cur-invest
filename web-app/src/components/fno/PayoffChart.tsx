type Point = { spot: number; pnl: number }

type Props = {
  points: Point[]
  height?: number
}

/** Expiry payoff diagram for long option / futures. */
export function PayoffChart({ points, height = 140 }: Props) {
  if (points.length < 2) {
    return (
      <div className="flex items-center justify-center text-xs text-muted" style={{ height }}>
        Payoff unavailable
      </div>
    )
  }
  const width = 400
  const pad = 12
  const xs = points.map((p) => p.spot)
  const ys = points.map((p) => p.pnl)
  const minX = Math.min(...xs)
  const maxX = Math.max(...xs)
  const minY = Math.min(...ys, 0)
  const maxY = Math.max(...ys, 0)
  const dx = maxX - minX || 1
  const dy = maxY - minY || 1

  const sx = (x: number) => pad + ((x - minX) / dx) * (width - pad * 2)
  const sy = (y: number) => height - pad - ((y - minY) / dy) * (height - pad * 2)

  const line = points.map((p, i) => `${i === 0 ? 'M' : 'L'} ${sx(p.spot)} ${sy(p.pnl)}`).join(' ')
  const zeroY = sy(0)

  return (
    <svg viewBox={`0 0 ${width} ${height}`} className="h-full w-full" role="img" aria-label="Payoff chart">
      <line x1={pad} y1={zeroY} x2={width - pad} y2={zeroY} stroke="rgba(148,163,184,0.35)" strokeDasharray="4 4" />
      <path d={line} fill="none" stroke="#c6ff00" strokeWidth="2" />
      <circle cx={sx(points[Math.floor(points.length / 2)].spot)} cy={sy(points[Math.floor(points.length / 2)].pnl)} r="3" fill="#c6ff00" />
    </svg>
  )
}
