import { useState } from 'react'
import { Link, NavLink } from 'react-router-dom'
import { Menu, X } from 'lucide-react'
import { Button } from '../ui/Button'
import { useAuth } from '../../context/AuthContext'

const links = [
  { to: '/#features', label: 'Features' },
  { to: '/#products', label: 'Products' },
  { to: '/#tools', label: 'Tools' },
  { to: '/pricing', label: 'Pricing' },
]

export function Navbar() {
  const [open, setOpen] = useState(false)
  const { isAuthenticated, practiceReady } = useAuth()

  return (
    <header className="sticky top-0 z-50 border-b border-white/5 glass">
      <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3 lg:px-6">
        <Link to="/" className="flex items-center gap-2">
          <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-brand-lime text-brand-ink font-extrabold text-sm">
            CBW
          </div>
          <div className="leading-tight">
            <div className="font-bold text-white">Capital BullWave</div>
            <div className="text-[10px] uppercase tracking-wider text-muted">BullWave Invest</div>
          </div>
        </Link>

        <nav className="hidden items-center gap-6 md:flex">
          {links.map((l) => (
            <NavLink
              key={l.to}
              to={l.to}
              className="text-sm text-muted transition hover:text-white"
            >
              {l.label}
            </NavLink>
          ))}
        </nav>

        <div className="hidden items-center gap-3 md:flex">
          {practiceReady ? (
            <Button to="/app" size="sm">
              Open Paper Trading
            </Button>
          ) : isAuthenticated ? (
            <Button to="/app/onboarding" size="sm" variant="secondary">
              Complete Setup
            </Button>
          ) : (
            <>
              <Button to="/login" variant="ghost" size="sm">
                Sign in
              </Button>
              <Button to="/login" size="sm" className="pulse-cta">
                Start Free
              </Button>
            </>
          )}
        </div>

        <button
          type="button"
          className="md:hidden rounded-lg p-2 text-muted hover:bg-white/5"
          onClick={() => setOpen(!open)}
          aria-label="Menu"
        >
          {open ? <X size={22} /> : <Menu size={22} />}
        </button>
      </div>

      {open && (
        <div className="border-t border-white/5 px-4 py-4 md:hidden">
          <div className="flex flex-col gap-3">
            {links.map((l) => (
              <Link key={l.to} to={l.to} className="text-sm text-muted" onClick={() => setOpen(false)}>
                {l.label}
              </Link>
            ))}
            <Button to={practiceReady ? '/app' : '/login'} size="sm" className="w-full">
              {practiceReady ? 'Open Paper Trading' : 'Start Free'}
            </Button>
          </div>
        </div>
      )}
    </header>
  )
}
