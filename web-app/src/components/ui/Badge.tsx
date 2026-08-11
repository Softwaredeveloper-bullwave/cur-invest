import type { ReactNode } from 'react'

export function Badge({
  children,
  tone = 'lime',
}: {
  children: ReactNode
  tone?: 'lime' | 'gold' | 'muted'
}) {
  const tones = {
    lime: 'bg-brand-lime/15 text-brand-lime border-brand-lime/30',
    gold: 'bg-brand-gold/15 text-brand-gold border-brand-gold/30',
    muted: 'bg-white/5 text-muted border-white/10',
  }
  return (
    <span
      className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium ${tones[tone]}`}
    >
      {children}
    </span>
  )
}
