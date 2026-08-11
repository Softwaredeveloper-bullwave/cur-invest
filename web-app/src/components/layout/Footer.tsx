import { Link } from 'react-router-dom'

export function Footer() {
  return (
    <footer className="border-t border-white/5 bg-surface/50">
      <div className="mx-auto grid max-w-6xl gap-8 px-4 py-12 md:grid-cols-4 lg:px-6">
        <div className="md:col-span-2">
          <div className="mb-3 flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-brand-lime text-brand-ink text-xs font-extrabold">
              CBW
            </div>
            <span className="font-bold">Capital BullWave</span>
          </div>
          <p className="max-w-sm text-sm text-muted">
            Learn, practice with paper trading, and invest with purpose. Real brokerage launching
            soon — SEBI license in progress.
          </p>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Product</h4>
          <ul className="space-y-2 text-sm text-muted">
            <li>
              <Link to="/#features" className="hover:text-white">
                Features
              </Link>
            </li>
            <li>
              <Link to="/pricing" className="hover:text-white">
                Pricing
              </Link>
            </li>
            <li>
              <Link to="/app" className="hover:text-white">
                Paper Trading
              </Link>
            </li>
          </ul>
        </div>
        <div>
          <h4 className="mb-3 text-sm font-semibold">Legal</h4>
          <ul className="space-y-2 text-sm text-muted">
            <li>
              <Link to="/privacy" className="hover:text-white">
                Privacy
              </Link>
            </li>
            <li>
              <Link to="/terms" className="hover:text-white">
                Terms
              </Link>
            </li>
            <li>
              <Link to="/support" className="hover:text-white">
                Support
              </Link>
            </li>
          </ul>
        </div>
      </div>
      <div className="border-t border-white/5 py-4 text-center text-xs text-muted">
        © {new Date().getFullYear()} Capital BullWave. All rights reserved. Not a SEBI-registered
        broker yet — practice mode only on web.
      </div>
    </footer>
  )
}
