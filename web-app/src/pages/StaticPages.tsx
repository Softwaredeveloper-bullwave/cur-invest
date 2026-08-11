import { Navbar } from '../components/layout/Navbar'
import { Footer } from '../components/layout/Footer'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'

export function PricingPage() {
  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-4xl px-4 py-16 lg:px-6">
        <h1 className="text-3xl font-bold">Transparent Pricing</h1>
        <p className="mt-2 text-muted">No hidden fees. Practice free today.</p>

        <div className="mt-10 grid gap-6 md:grid-cols-2">
          <div className="glass rounded-2xl p-6">
            <Badge>Paper Trading</Badge>
            <h2 className="mt-4 text-2xl font-bold text-brand-lime">Free</h2>
            <p className="mt-2 text-sm text-muted">
              ₹1,00,000 virtual wallet, unlimited practice trades on web and app.
            </p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>• Live market quotes</li>
              <li>• Portfolio P&L tracking</li>
              <li>• Phone + email signup on web</li>
            </ul>
            <Button to="/login" className="mt-6 w-full">
              Start Free
            </Button>
          </div>

          <div className="glass rounded-2xl border-brand-gold/30 p-6">
            <Badge tone="gold">Live Trading</Badge>
            <h2 className="mt-4 text-2xl font-bold">Launching soon</h2>
            <p className="mt-2 text-sm text-muted">
              Real Demat, NSE/BSE execution, UPI deposits — after SEBI license approval.
            </p>
            <ul className="mt-4 space-y-2 text-sm text-muted">
              <li>• Full KYC required</li>
              <li>• Cashfree UPI payments</li>
              <li>• Featured investment plans</li>
            </ul>
            <Button to="/app/live" variant="secondary" className="mt-6 w-full">
              Get notified
            </Button>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}

export function SupportPage() {
  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-3xl px-4 py-16 lg:px-6">
        <h1 className="text-3xl font-bold">Support</h1>
        <p className="mt-4 text-muted">
          Email us at{' '}
          <a href="mailto:support@capitalbullwave.com" className="text-brand-lime">
            support@capitalbullwave.com
          </a>
        </p>
        <p className="mt-4 text-sm text-muted">
          For KYC and account issues, use the BullWave Invest mobile app support section.
        </p>
      </main>
      <Footer />
    </>
  )
}

export function LegalPage({ title, body }: { title: string; body: string }) {
  return (
    <>
      <Navbar />
      <main className="mx-auto max-w-3xl px-4 py-16 lg:px-6 prose prose-invert">
        <h1 className="text-3xl font-bold text-white">{title}</h1>
        <div className="mt-6 space-y-4 text-sm text-muted whitespace-pre-line">{body}</div>
      </main>
      <Footer />
    </>
  )
}

const privacy = `Capital BullWave ("we") collects phone number, email, and profile information for account creation. KYC documents are collected via the mobile app for compliance.

We use industry-standard security and do not sell your personal data. Payment data is processed by Cashfree when live wallet features are enabled.

Contact: support@capitalbullwave.com`

const terms = `By using Capital BullWave you agree to use paper trading for learning only. Virtual trades do not represent real investments.

Live trading will require full KYC and SEBI-compliant disclosures when available. We are not a registered broker until license approval.

You must be 18+ and an Indian resident to use our services.`

export function PrivacyPage() {
  return <LegalPage title="Privacy Policy" body={privacy} />
}

export function TermsPage() {
  return <LegalPage title="Terms of Service" body={terms} />
}
