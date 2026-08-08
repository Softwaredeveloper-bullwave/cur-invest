# Website Build Prompt — Capital BullWave Marketing Site

**Copy everything below the line into a new Cursor chat / folder to build a Lemonn-style marketing website for BullWave Capital.**

---

## PROMPT START (copy from here)

Build a modern, production-quality marketing website for **Capital BullWave (BullWave Invest)** — similar in structure and polish to https://lemonn.co.in/ but fully customized for our product.

### Reference site (structure & quality bar only)
Study https://lemonn.co.in/ for:
- Hero with app mockup + primary CTA
- Trust badges (SEBI, security, ratings)
- Product tabs/carousel (Stocks, F&O, Goals, etc.)
- Smart tools section
- Pro features grid
- Trending market widget
- Calculator section
- Testimonials carousel
- Footer with legal links + app store buttons
- Clean fintech aesthetic, fast scroll animations, mobile-first

**Do NOT copy Lemonn branding, copy, or colors.** Build for BullWave only.

---

### Brand identity

| Item | Value |
|------|--------|
| **Product name** | Capital BullWave |
| **Short name / logo** | CBW |
| **App name** | BullWave Invest |
| **Tagline options** | "Learn. Practice. Invest with purpose." / "Smart investing for India's next generation" |
| **Domain** | https://api.capitalbullwave.com (API) — marketing site: **capitalbullwave.com** or **bullwave.in** |
| **Target audience** | Indian retail investors 22–45 — beginners + aspiring active traders |
| **Tone** | Premium, trustworthy, beginner-friendly but pro-capable — not gamified crypto vibes |

### Color palette (match Flutter app)

```css
--brand-lime: #C6FF00;        /* Primary CTA, accents */
--brand-ink: #0A0A0A;         /* Text on lime, dark hero */
--brand-gold: #FFB830;        /* Highlights, warnings */
--brand-magenta: #A855F7;     /* Secondary accent */
--bg-midnight: #060A14;       /* Dark sections / hero */
--bg-surface: #0F1628;        /* Cards on dark */
--text-light: #F5F5F5;
--text-muted: #94A3B8;
--success: #22C55E;
```

**Typography:** Inter or similar (Google Fonts) — bold headings, clean body.

---

### What our application actually does (use ONLY these — no fake features)

#### Core journey
1. **Sign up** — Phone OTP (Infobip SMS) → Email verify → Complete profile
2. **KYC** — PAN → Aadhaar DigiLocker → Bank verify → Live selfie + UPI (manual admin review) → Name match
3. **F&O eligibility** — Separate income/portfolio proof before options trading
4. **Invest & trade** — Paper/practice wallet for stocks, F&O, commodities (live brokerage coming soon — phrase as "practice mode" or "early access")
5. **Real money** — Wallet deposit (Cashfree/Razorpay UPI), featured investment plans, goal-based savings, bank withdraw

#### App modules to showcase on website

| Section | Features |
|---------|----------|
| **Home dashboard** | Portfolio summary, pending KYC actions, market overview, trending stocks, goals due, featured plans |
| **Markets** | Stock search, watchlist, charts (TradingView-ready), heat map, economic calendar, news, voice search |
| **Trading (practice)** | Equity buy/sell pad, option chain, scalper mode (SL/target/trailing), commodity trading, paper competitions |
| **Portfolio** | Holdings, P&L, plan allocations, order history |
| **Wallet** | UPI deposit, withdraw to verified bank, transaction history |
| **Goal plans** | Templates: home, education, marriage, vehicle, retirement — monthly contributions + reminders |
| **Featured plans** | Curated managed investment subscriptions with FAQ |
| **Research Vault** | Education articles by category, quizzes with marks/answers |
| **AI assistant** | Chat + voice (STT/TTS) — portfolio help, stock questions, BullWave feature guide |
| **Profile** | KYC status, bank details, referrals, settings, support tickets |

#### Trust & compliance (honest — don't overclaim)
- KYC via Eko / Cashfree Secure ID + DigiLocker
- Manual compliance review for selfie & UPI
- Cashfree payments & payouts
- PostgreSQL-backed secure backend
- **Do NOT claim "SEBI registered broker" unless we add it later** — use "KYC-ready platform" / "Built for Indian compliance"

#### Differentiators vs typical brokers (Lemonn, Zerodha, Groww)
- **AI assistant with voice** — ask anything about markets or your portfolio
- **Goal-based wealth planning** — not just trading
- **Research Vault + quizzes** — learn before you earn
- **Paper trading competitions** — practice without risk
- **Learn → Practice → Invest** journey (not "open Demat and trade" only)

---

### Required website pages

```
/                     → Landing (main marketing page, Lemonn-style single scroll OR multi-section)
/features             → Feature deep-dive (optional separate page)
/pricing              → Plans, featured investment plans, goal tiers (transparent fees)
/about                → Company story, mission
/kyc                  → How KYC works (PAN, Aadhaar, bank, selfie — build trust)
/download             → App Store + Play Store links + QR code
/blog                 → Market insights / education (can start with 3 placeholder posts)
/support              → FAQ, contact email, ticket link
/privacy              → Privacy policy
/terms                → Terms of service
/refund               → Refund policy (for wallet/plans)
```

---

### Landing page sections (mirror Lemonn flow, BullWave content)

#### 1. Header
- Logo: **Capital BullWave** (CBW mark)
- Nav: Features | Goals | Research Vault | AI Assistant | Pricing | Download
- CTA button: **Get the App** / **Start Free**

#### 2. Hero
- Headline: **"Learn. Practice. Invest — All in One App"**
- Sub: Open your account, complete KYC in minutes, start with paper trading or goal-based plans — no complexity.
- CTA: **Download App** + **See Features**
- Phone mockup showing home screen (dark theme + lime accents)
- Trust row: "Secure KYC" | "UPI Payments" | "AI-Powered" | "Made for India"

#### 3. Why BullWave? (4 cards — like Lemonn "Why Investors Choose")
- **All-in-One Journey** — KYC, wallet, markets, goals, education in one app
- **Learn Before You Trade** — Research Vault, quizzes, paper trading competitions
- **AI That Knows Your Portfolio** — Chat and voice assistant for real answers
- **Transparent & Secure** — Cashfree payments, verified bank withdraw, manual compliance review

#### 4. Product carousel (auto-scroll, pause on hover)
Tabs/cards:
- **Stocks & Markets** — Search 50+ Nifty stocks, charts, watchlist, news
- **Practice Trading** — Paper wallet, scalper mode, F&O option chain — zero risk learning
- **Goal Plans** — Save for home, education, retirement with monthly reminders
- **Featured Plans** — Curated investment strategies managed by BullWave
- **Research Vault** — Articles, quizzes, earn marks as you learn
- **AI Assistant** — Voice + chat — your 24/7 investing copilot

#### 5. Smart Money Tools
- SIP / Returns calculator (interactive — like Lemonn)
- Goal planner calculator ("Save ₹X/month for Y years")
- Portfolio health preview (diversification score — teaser)

#### 6. Pro Features grid (our version — honest)
- **Scalper mode** — SL, target, trailing stop on paper trades
- **Option chain** — NIFTY, BANKNIFTY, FINNIFTY
- **Price alerts** — Never miss a level
- **Copy trading** — Follow strategies (coming soon badge if not live)
- **Voice search** — Find stocks by speaking
- **F&O gate** — Income-verified options access for safety

#### 7. Trending Today (live or mock)
- NIFTY 50 / SENSEX / BANKNIFTY tabs
- Top gainers / losers (can fetch from API: `GET https://api.capitalbullwave.com/api/v1/...` or static mock for v1)

#### 8. KYC explainer (unique section — Lemonn doesn't emphasize this much)
Visual 5-step flow:
1. Phone OTP → 2. Email verify → 3. PAN + Aadhaar → 4. Bank verify → 5. Selfie + UPI review
Copy: "We verify every account manually for your security."

#### 9. Testimonials (placeholder — 6 cards)
Indian names, focus on: easy KYC, AI help, goal plans, learning vault, paper trading

#### 10. FAQ accordion
- Is BullWave a broker? → Practice trading today; live brokerage roadmap
- How do I add money? → UPI via Cashfree
- How does KYC work? → Step list
- Is my data safe? → Encryption, compliance
- What is paper trading? → Virtual wallet explanation

#### 11. Final CTA
**"Ready to start? Download Capital BullWave."**
App Store + Google Play buttons (placeholder links until published)

#### 12. Footer
- Product: Features, Pricing, Download, Blog
- Legal: Privacy, Terms, Refund
- Support: support@ / help center
- Social: Twitter, LinkedIn, Instagram (placeholder)
- © 2026 Capital BullWave. All rights reserved.

---

### Technical requirements

**Stack (pick one — recommend Next.js or Vite+React):**
```
Option A: Next.js 14+ (App Router) + Tailwind CSS + Framer Motion
Option B: Vite + React + Tailwind + React Router
Option C: Astro (static, very fast marketing site)
```

**Must have:**
- Fully responsive (mobile-first)
- Dark theme default (match app — midnight + lime)
- Lighthouse score 90+ (performance, SEO)
- SEO meta tags, Open Graph, Twitter cards
- `robots.txt`, `sitemap.xml`
- Smooth scroll animations (subtle — not heavy)
- Accessible (WCAG AA contrast on lime buttons: use `#0A0A0A` text on `#C6FF00` bg)

**Optional integrations:**
- Link CTAs to app deep links when live
- `GET https://api.capitalbullwave.com/health/` badge ("API Status: Online")
- Newsletter signup (Brevo/Mailchimp placeholder)
- Google Analytics / Plausible

**Project structure:**
```
bullwave-website/
├── public/
│   ├── logo.svg
│   ├── app-mockup.png
│   └── og-image.png
├── src/
│   ├── components/   (Hero, FeatureCard, Calculator, FAQ, Footer, Navbar)
│   ├── sections/     (one file per landing section)
│   ├── pages/
│   └── styles/
├── package.json
└── README.md
```

---

### Content rules

1. **Never claim SEBI broker registration** unless explicitly told — use "investment platform" / "KYC-compliant"
2. **Paper trading** = practice mode with virtual wallet — say it clearly
3. **Live trading** = "Coming soon" or "Early access" unless broker license exists
4. **AI** = assistant for education + portfolio help — not "guaranteed returns"
5. All ₹ amounts in Indian format (₹10,000 not $10,000)
6. Use Indian English (" lakh ", " crore " where relevant)

---

### App store copy (for download section)

**Google Play short description:**
> Capital BullWave — Learn, practice, and invest with AI-powered guidance, goal plans, and Research Vault.

**App Store subtitle:**
> Smart investing for India

---

### Deliverables

1. Complete responsive marketing website with all sections above
2. Reusable component library matching BullWave design tokens
3. README with `npm install && npm run dev` instructions
4. Placeholder images noted where real screenshots needed
5. Deploy-ready config (Vercel / Netlify / nginx static)

---

### Assets to request from app team (or use placeholders)

- [ ] CBW logo SVG (from `lib/core/widgets/app_brand_logo.dart` style)
- [ ] 3–5 app screenshots (home, markets, goals, AI chat, KYC)
- [ ] App Store / Play Store URLs when published
- [ ] Support email address
- [ ] Company legal name for footer

---

## PROMPT END

---

### How to use this prompt

1. Create a new folder: `bullwave-website/` (sibling to `investingapp/`)
2. Open it in Cursor
3. Paste **everything between PROMPT START and PROMPT END** into Agent/Composer
4. Add: *"Build the full site. Start with Next.js + Tailwind. Create the landing page first."*
5. Replace placeholder screenshots with real app captures later

### Optional add-on prompts

**For blog only:**
> Add a `/blog` section with 3 SEO articles: "What is paper trading?", "How to complete KYC on BullWave", "Goal-based investing vs trading"

**For API-connected trending widget:**
> Connect the Trending section to `https://api.capitalbullwave.com/api/v1/stocks/market/overview/` (or mock if CORS blocked — use Next.js API route proxy)

**For admin parity page:**
> Add `/for-business` partner page similar to Lemonn's "Join As A Partner"
