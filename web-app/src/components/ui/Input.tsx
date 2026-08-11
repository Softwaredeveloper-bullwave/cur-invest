import { forwardRef, type InputHTMLAttributes } from 'react'

type Props = InputHTMLAttributes<HTMLInputElement> & {
  label?: string
  hint?: string
  error?: string
}

export const Input = forwardRef<HTMLInputElement, Props>(function Input(
  { label, hint, error, className = '', ...props },
  ref,
) {
  return (
    <label className="block space-y-1.5">
      {label && <span className="text-sm font-medium text-muted">{label}</span>}
      <input
        ref={ref}
        className={`w-full rounded-xl border border-white/10 bg-surface px-4 py-3 text-white placeholder:text-muted/60 outline-none transition focus:border-brand-lime/50 focus:ring-2 focus:ring-brand-lime/20 ${className}`}
        {...props}
      />
      {error && <span className="text-sm text-danger">{error}</span>}
      {hint && !error && <span className="text-xs text-muted">{hint}</span>}
    </label>
  )
})
