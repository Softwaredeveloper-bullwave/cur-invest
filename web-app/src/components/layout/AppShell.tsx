import { Outlet, Navigate, Link, NavLink } from 'react-router-dom'
import { TrendingUp, Wallet, LineChart, LogOut, Rocket, Layers } from 'lucide-react'
import { useAuth } from '../../context/AuthContext'
import { Badge } from '../ui/Badge'

const nav = [
  { to: '/app', label: 'Dashboard', icon: TrendingUp, end: true },
  { to: '/app/markets', label: 'Markets', icon: LineChart },
  { to: '/app/fno', label: 'F&O', icon: Layers },
  { to: '/app/portfolio', label: 'Portfolio', icon: Wallet },
  { to: '/app/live', label: 'Live Trading', icon: Rocket },
]

export function AppShell() {
  const { user, logout, practiceReady, loading } = useAuth()

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-midnight">
        <div className="h-8 w-8 animate-spin rounded-full border-2 border-brand-lime border-t-transparent" />
      </div>
    )
  }

  if (!user) return <Navigate to="/login" replace />
  if (!practiceReady) return <Navigate to="/app/onboarding" replace />

  return (
    <div className="min-h-screen bg-midnight">
      <header className="sticky top-0 z-40 border-b border-white/5 glass">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-4 py-3">
          <Link to="/app" className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-lime text-brand-ink text-xs font-extrabold">
              CBW
            </div>
            <div>
              <div className="text-sm font-bold">Paper Trading</div>
              <div className="text-[10px] text-muted">{user.name || user.phone}</div>
            </div>
          </Link>
          <div className="flex items-center gap-3">
            <Badge tone="gold">Practice Mode</Badge>
            <button
              type="button"
              onClick={logout}
              className="rounded-lg p-2 text-muted hover:bg-white/5 hover:text-white"
              aria-label="Logout"
            >
              <LogOut size={18} />
            </button>
          </div>
        </div>
        <nav className="mx-auto flex max-w-6xl gap-1 overflow-x-auto px-4 pb-2">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-1.5 whitespace-nowrap rounded-lg px-3 py-2 text-sm transition ${
                  isActive
                    ? 'bg-brand-lime/15 text-brand-lime'
                    : 'text-muted hover:bg-white/5 hover:text-white'
                }`
              }
            >
              <Icon size={16} />
              {label}
            </NavLink>
          ))}
        </nav>
      </header>
      <main className="mx-auto max-w-6xl px-4 py-6 lg:px-6">
        <Outlet />
      </main>
    </div>
  )
}
