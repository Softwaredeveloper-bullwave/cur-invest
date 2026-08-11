import { ArrowRight, Shield, Sparkles, Target, BookOpen, Bot, Trophy } from 'lucide-react'
import { Button } from '../ui/Button'
import { Badge } from '../ui/Badge'

export function HeroSection() {
  return (
    <section className="gradient-hero relative overflow-hidden px-4 pb-16 pt-12 lg:px-6 lg:pb-24 lg:pt-16">
      <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-2">
        <div className="animate-fade-up space-y-6">
          <Badge tone="gold">Real trading — Launching soon</Badge>
          <h1 className="text-4xl font-extrabold leading-tight tracking-tight md:text-5xl lg:text-6xl">
            Learn. Practice.{' '}
            <span className="text-brand-lime">Invest with purpose.</span>
          </h1>
          <p className="max-w-lg text-lg text-muted">
            Fast & smart investing for everyone. Start with{' '}
            <strong className="text-white">₹1,00,000 virtual money</strong> — paper trade stocks
            with zero risk while we prepare for SEBI-licensed live trading.
          </p>
          <div className="flex flex-wrap gap-3">
            <Button to="/login" size="lg" className="pulse-cta">
              Start Paper Trading Free
              <ArrowRight size={18} />
            </Button>
            <Button to="/#products" variant="secondary" size="lg">
              Explore Features
            </Button>
          </div>
          <div className="flex flex-wrap gap-4 pt-2 text-xs text-muted">
            <span className="flex items-center gap-1">
              <Shield size={14} className="text-brand-lime" /> Secure KYC on app
            </span>
            <span className="flex items-center gap-1">
              <Sparkles size={14} className="text-brand-lime" /> AI Assistant
            </span>
            <span className="flex items-center gap-1">
              <Target size={14} className="text-brand-lime" /> Goal Plans
            </span>
          </div>
        </div>

        <div className="relative mx-auto w-full max-w-sm lg:max-w-md">
          <div className="absolute -inset-4 rounded-3xl bg-brand-lime/10 blur-3xl" />
          <div className="relative rounded-3xl border border-white/10 bg-surface p-4 shadow-2xl">
            <div className="mb-3 flex items-center justify-between">
              <span className="text-xs font-medium text-muted">Practice Wallet</span>
              <Badge>Live on web</Badge>
            </div>
            <div className="mb-4 text-3xl font-bold text-brand-lime">₹1,00,000</div>
            <div className="space-y-2 rounded-xl bg-midnight/80 p-3 text-sm">
              <div className="flex justify-between">
                <span className="text-muted">RELIANCE</span>
                <span className="text-success">+2.4%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted">TCS</span>
                <span className="text-success">+1.1%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-muted">HDFCBANK</span>
                <span className="text-danger">-0.6%</span>
              </div>
            </div>
            <div className="mt-4 grid grid-cols-2 gap-2">
              <div className="rounded-lg bg-brand-lime py-2 text-center text-sm font-semibold text-brand-ink">
                Buy
              </div>
              <div className="rounded-lg border border-white/10 py-2 text-center text-sm">Sell</div>
            </div>
          </div>
        </div>
      </div>
    </section>
  )
}

const whyCards = [
  {
    icon: Target,
    title: 'All-in-One Journey',
    desc: 'KYC, wallet, markets, goals, and education in one platform — mobile app + web paper trading.',
  },
  {
    icon: BookOpen,
    title: 'Learn Before You Trade',
    desc: 'Research Vault, quizzes, and paper trading competitions — build skill without risk.',
  },
  {
    icon: Bot,
    title: 'AI That Knows Your Portfolio',
    desc: 'Chat and voice assistant for market questions, portfolio help, and BullWave feature guides.',
  },
  {
    icon: Shield,
    title: 'Transparent & Secure',
    desc: 'Cashfree payments, verified bank withdraw, DigiLocker KYC — built for Indian compliance.',
  },
]

export function WhySection() {
  return (
    <section id="features" className="px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-2 text-center text-3xl font-bold">Why Investors Choose BullWave?</h2>
        <p className="mb-10 text-center text-muted">Premium tools without the complexity.</p>
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {whyCards.map(({ icon: Icon, title, desc }) => (
            <div key={title} className="glass card-hover rounded-2xl p-5">
              <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-xl bg-brand-lime/15 text-brand-lime">
                <Icon size={20} />
              </div>
              <h3 className="mb-2 font-semibold">{title}</h3>
              <p className="text-sm text-muted">{desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

const products = [
  {
    title: 'Stocks & Markets',
    desc: 'Search Nifty 50 stocks, live quotes, charts, watchlist, and market news.',
    tag: 'Paper + Live soon',
  },
  {
    title: 'Practice Trading',
    desc: '₹1L virtual wallet, buy/sell pad, scalper mode, F&O chain — zero real money risk.',
    tag: 'Available now',
  },
  {
    title: 'Goal Plans',
    desc: 'Save for home, education, retirement with monthly reminders and progress tracking.',
    tag: 'App',
  },
  {
    title: 'Research Vault',
    desc: 'Articles by category, quizzes with marks — learn before you earn.',
    tag: 'App',
  },
  {
    title: 'AI Assistant',
    desc: 'Voice + chat — your 24/7 investing copilot for stocks and app help.',
    tag: 'App',
  },
  {
    title: 'Live Trading',
    desc: 'Real NSE/BSE execution, Demat, UPI deposits — coming after SEBI license.',
    tag: 'Launching soon',
  },
]

export function ProductsSection() {
  return (
    <section id="products" className="bg-surface/30 px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-2 text-center text-3xl font-bold">Start Your Investing Journey</h2>
        <p className="mb-10 text-center text-muted">Everything you need — practice today, trade live tomorrow.</p>
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {products.map((p) => (
            <div key={p.title} className="glass card-hover rounded-2xl p-6">
              <Badge tone={p.tag === 'Launching soon' ? 'gold' : 'lime'}>{p.tag}</Badge>
              <h3 className="mt-3 text-xl font-semibold">{p.title}</h3>
              <p className="mt-2 text-sm text-muted">{p.desc}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export function ToolsSection() {
  return (
    <section id="tools" className="px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-10 text-center text-3xl font-bold">Smart Money Tools</h2>
        <div className="grid gap-6 lg:grid-cols-3">
          {[
            {
              title: 'SIP Calculator',
              desc: 'Estimate future returns on monthly investments with clear projections.',
            },
            {
              title: 'Goal Planner',
              desc: 'See how much to save each month for home, education, or retirement.',
            },
            {
              title: 'Portfolio Health',
              desc: 'Diversification score and risk preview — available in the mobile app.',
            },
          ].map((t) => (
            <div key={t.title} className="glass rounded-2xl p-6">
              <h3 className="font-semibold">{t.title}</h3>
              <p className="mt-2 text-sm text-muted">{t.desc}</p>
              <p className="mt-4 text-xs text-brand-gold">Full calculators in app — web coming soon</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

const proFeatures = [
  'Scalper mode — SL, target, trailing stop on paper trades',
  'Option chain — NIFTY, BANKNIFTY, FINNIFTY',
  'Price alerts — never miss a level',
  'Paper trading competitions with friends',
  'Voice search — find stocks by speaking',
  'F&O gate — income-verified options access',
]

export function ProFeaturesSection() {
  return (
    <section className="bg-surface/30 px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-2 text-center text-3xl font-bold">Pro Tools for Every Strategy</h2>
        <p className="mb-10 text-center text-muted">Practice with pro-grade features — before real money.</p>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {proFeatures.map((f) => (
            <div
              key={f}
              className="flex items-start gap-3 rounded-xl border border-white/5 bg-midnight/50 p-4"
            >
              <Trophy size={18} className="mt-0.5 shrink-0 text-brand-lime" />
              <span className="text-sm">{f}</span>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}

export function TrendingSection() {
  return (
    <section className="px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl text-center">
        <h2 className="mb-2 text-3xl font-bold">What&apos;s Trending Today</h2>
        <p className="mb-8 text-muted">
          Live NIFTY 50 data inside the app and paper trading dashboard.
        </p>
        <Button to="/login" size="lg">
          Sign in to see live markets
        </Button>
      </div>
    </section>
  )
}

const testimonials = [
  {
    name: 'Priya S.',
    text: 'Paper trading helped me learn order types before putting real money. The AI assistant explains everything clearly.',
  },
  {
    name: 'Rahul M.',
    text: 'Goal plans + practice wallet is the combo I needed. KYC on the app was smooth with DigiLocker.',
  },
  {
    name: 'Ananya K.',
    text: 'Research Vault quizzes made investing less scary. Waiting for live trading — practice mode is already great.',
  },
]

export function TestimonialsSection() {
  return (
    <section className="bg-surface/30 px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-6xl">
        <h2 className="mb-10 text-center text-3xl font-bold">Trusted by Learners & Traders</h2>
        <div className="grid gap-4 md:grid-cols-3">
          {testimonials.map((t) => (
            <blockquote key={t.name} className="glass rounded-2xl p-6">
              <p className="text-sm text-muted">&ldquo;{t.text}&rdquo;</p>
              <footer className="mt-4 text-sm font-semibold">— {t.name}</footer>
            </blockquote>
          ))}
        </div>
      </div>
    </section>
  )
}

const faqs = [
  {
    q: 'Is BullWave a SEBI-registered broker?',
    a: 'Not yet. We are applying for licenses. Today you can paper trade with virtual money. Live brokerage is launching soon.',
  },
  {
    q: 'What is paper trading?',
    a: 'Practice mode with ₹1,00,000 virtual wallet. Buy and sell stocks at live prices — no real money involved.',
  },
  {
    q: 'What do I need for web paper trading?',
    a: 'First verify your email (Gmail OTP), then verify your phone. Full KYC (PAN, Aadhaar, bank) is required on the mobile app and for live trading later.',
  },
  {
    q: 'Is my data safe?',
    a: 'Yes. PostgreSQL-backed secure backend, encrypted KYC via DigiLocker, and Cashfree for payments when live trading launches.',
  },
]

export function FaqSection() {
  return (
    <section className="px-4 py-16 lg:px-6">
      <div className="mx-auto max-w-3xl">
        <h2 className="mb-10 text-center text-3xl font-bold">FAQ</h2>
        <div className="space-y-4">
          {faqs.map((f) => (
            <details key={f.q} className="glass group rounded-xl p-4">
              <summary className="cursor-pointer font-medium marker:content-none">{f.q}</summary>
              <p className="mt-3 text-sm text-muted">{f.a}</p>
            </details>
          ))}
        </div>
      </div>
    </section>
  )
}

export function CtaSection() {
  return (
    <section className="gradient-hero px-4 py-20 lg:px-6">
      <div className="mx-auto max-w-3xl text-center">
        <Badge tone="gold">Live trading — Launching soon</Badge>
        <h2 className="mt-4 text-3xl font-bold md:text-4xl">Ready to practice? Start in 2 minutes.</h2>
        <p className="mt-3 text-muted">
          1. Enter phone → 2. Verify email → 3. Paper trade with ₹1 lakh virtual money.
        </p>
        <div className="mt-8 flex flex-wrap justify-center gap-3">
          <Button to="/login" size="lg">
            Start Paper Trading Free
          </Button>
          <Button to="/" variant="secondary" size="lg">
            Download app (coming soon)
          </Button>
        </div>
      </div>
    </section>
  )
}
