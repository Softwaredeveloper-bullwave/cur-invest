# Capital BullWave — Play Store Strategy & Roadmap

**Document version:** 1.0  
**Date:** 19 August 2026  
**App:** Capital BullWave (CBW) — Flutter (`bullwave_investing`)  
**Production API:** https://api.capitalbullwave.com/api/v1  

---

## 1. Executive Summary

You want to **publish on Google Play now** as a **paper trading / market research simulator**, while your **real trading / investment license** is pending. This is the correct strategy — but the **current app still shows real-money features** (Featured Plans with 36–48% returns, Wallet deposits, payment methods, Copy Trading). That is the main reason Google Play keeps rejecting the app.

**Bottom line:**

| Today (without license) | After license |
|------------------------|---------------|
| Paper trading simulator + live charts + research | Full brokerage + wallet + real plans |
| No deposits, no return promises, no payment UI | Cashfree payments live, KYC-gated real money |
| Store listing: “Paper Trading Simulator” | Store listing: “Investment Platform” (with license proof) |

---

## 2. Why Google Play Keeps Rejecting You

Google reviews **the installed APK/AAB**, not only your listing text. Common rejection reasons for your app:

### HIGH RISK (likely cause of rejection)

| # | Issue | Where in app |
|---|-------|--------------|
| 1 | **Fixed return promises** — 3%, 36%, 48% p.a. and 4% monthly | Featured Plans (Home + Plan detail screen) |
| 2 | **Investment product without license** — ₹10L–₹1Cr minimum plans | `featured_plans_catalog.dart`, Featured Plan screen |
| 3 | **Payment methods shown but misleading** — UPI, Card, Net Banking on plan screen when payments not active for public | Featured Plan screen |
| 4 | **Real wallet / Add Money / Withdraw** | Wallet tab, Deposit screen (Cashfree) |
| 5 | **Misleading onboarding** — “Up to 4% monthly returns”, “encrypted payouts” | Onboarding slides |
| 6 | **Copy Trading — allocate capital to traders** | Copy Trading screen |
| 7 | **Goal Plans — Earn 8–16% p.a.** with payment | Goals section |
| 8 | **Buy/Sell looks like live trading** but backend is paper-only | Stock detail Markets tab |

### MEDIUM RISK

- App name/icon mismatch (partially fixed in v1.0.5)
- KYC flow visible while claiming “paper only” — implies regulated broker
- Financial Services declaration in Play Console not matching app behavior
- Camera permission for KYC without clear in-app justification

### What Google expects for paper trading apps

- Clear **“SIMULATED / PAPER / NO REAL MONEY”** disclaimers
- No guaranteed or fixed returns
- No deposit / withdrawal flows unless licensed
- Store description must match installed app
- Category: Finance (Educational) or similar — not “Investment broker”

---

## 3. Current App — What Works vs What Is Real Money

### ✅ SAFE for paper-trading launch (keep)

| Feature | Notes |
|---------|-------|
| **Paper Trading hub** | Virtual funds, labeled “Practice” |
| **Paper Buy/Sell** (stocks) | Uses `placePaperTrade()` API |
| **Live market data** | Charts, watchlist, screener, news |
| **IPO calendar, economic calendar** | Informational |
| **Investment calculator & education docs** | Educational |
| **AI assistant** | Add “not financial advice” disclaimer |
| **Paper competitions / risk meter** | Virtual only |
| **Terms & Privacy** | Keep; align with actual product |

### ❌ MUST HIDE for paper-only Play launch

| Feature | Why |
|---------|-----|
| **Featured Plans** (Premier / Reserve / Crown) | Fixed returns = unlicensed investment product |
| **Wallet — Add Money / Withdraw** | Real money + Cashfree |
| **Deposit / Payment screens** | Financial Services policy |
| **Goal Plans with returns + Pay Now** | Fixed return savings product |
| **Copy Trading** | Capital allocation / advisory-like |
| **Full KYC onboarding** (PAN, bank, selfie) | Implies real brokerage — optional: light phone OTP only |
| **Onboarding slides mentioning returns/payouts** | Misleading claims |
| **Home “Featured Plans” carousel** | Same as above |
| **Transactions (real money)** | Hide until live |

### ⚠️ RELABEL (not just hide)

| Current | Change to |
|---------|-------------|
| Portfolio tab | **Paper Portfolio** + banner “Simulated — no real money” |
| Markets Buy/Sell | **Paper Buy / Paper Sell** |
| Wallet tab | Hide OR show **Practice Balance only** |
| Home wallet card “Tap to add funds” | **Practice balance** or remove |

---

## 4. Phase 1 Roadmap — Paper Trading Play Store Launch

**Goal:** Get app live on Play Store as **Capital BullWave — Paper Trading Simulator**

**Timeline estimate:** 2–4 weeks (dev + review)

### Step A — App changes (development)

1. **Add build flag:** `PAPER_ONLY=true` (dart-define)
   - Hides: Wallet deposit/withdraw, Featured Plans, Goals payments, Copy Trading, Cashfree checkout
   - Shows: Paper trading, charts, research, practice balance

2. **Remove from bottom nav / home:**
   - Featured Plans section
   - Goals “Earn 8–16%” promo
   - Wallet tab (or replace with Practice Wallet only)

3. **Rewrite copy:**
   - Onboarding: remove “4% monthly returns”, “payouts”
   - Splash / About: “Paper trading simulator for Indian markets”
   - Brand tagline: no “Grow wealth with guaranteed returns”

4. **Add persistent disclaimer** on trade screens:
   > “Simulated trading only. No real money. Not a SEBI-registered broker.”

5. **Optional:** Remove `flutter_cashfree_pg_sdk` from paper-only build (reduces Play scrutiny)

6. **Version:** Bump to 1.1.0+6 with release notes “Paper trading mode”

### Step B — Google Play Console

1. **App category:** Finance → choose subcategory that fits “simulation/education”
2. **Store listing title:** `Capital BullWave — Paper Trading`
3. **Short description:** Paper trading simulator with live NSE/BSE charts. Practice with virtual money. No real deposits.
4. **Full description:** Must NOT mention:
   - Fixed returns / % p.a.
   - Investment plans / Premier / Crown
   - Wallet funding / UPI deposits
   - “KYC-verified investing”
5. **Screenshots:** Only paper trading, charts, watchlist — NO plan screens, NO payment screens
6. **Financial Services declaration:**
   - If no real money in APK → declare **no financial features** or “simulation only”
   - Do NOT declare payment processing if Cashfree UI is removed
7. **Data safety:** Declare phone number (OTP), optional camera if kept for profile photo
8. **Content rating:** Complete questionnaire honestly
9. **Target audience:** 18+ (finance apps)

### Step C — Compliance documents (keep ready)

- Terms of Service (already in app — ensure “not SEBI registered” is prominent)
- Privacy Policy (URL on Play Console)
- Support email (required)

### Step D — Submit & review

1. Upload AAB (signed release)
2. Internal testing → closed testing (10+ testers, 14 days optional but helps)
3. Production release
4. If rejected: read **exact policy name** in email, fix only that item, resubmit with explanation letter

---

## 5. Phase 2 Roadmap — After License Approval

**Goal:** Enable real trading, wallet, investment plans legally

**Prerequisites before flipping switch:**

| License / approval | Required for |
|--------------------|--------------|
| SEBI registration (broker / IA / PMS as applicable) | Real stock trading, advisory |
| RBI / payment aggregator compliance | Wallet deposits |
| Cashfree production KYC + PG live | Deposits, plan payments |
| Updated Terms + Risk disclosures | All real-money flows |

### Step A — Backend & payments

1. Cashfree **production** keys on server
2. Webhook signature verification live
3. KYC pipeline production (PAN, Aadhaar, bank verified)
4. Real order routing to broker API (when ready)

### Step B — App changes

1. Remove `PAPER_ONLY` flag or set `false` in production build
2. Re-enable: Wallet, Featured Plans, Goals, Copy Trading (if licensed for each)
3. Update store listing with license numbers
4. Play Console: update Financial Services declaration — upload license proof
5. Add in-app risk disclosures before first real deposit

### Step C — Play Store update

1. New AAB version (e.g. 2.0.0)
2. Update description to full platform
3. New screenshots including wallet (only after payments work)
4. May trigger **enhanced review** — keep license PDF ready

---

## 6. Process Flow Diagrams

### Phase 1 — User journey (paper only)

```
Install → Splash → Onboarding → Login (OTP) → Home
                                              ↓
                                    Markets / Paper Trade
                                              ↓
                              Virtual portfolio + live charts
                              (NO deposit, NO plans, NO payments)
```

### Phase 2 — User journey (after license)

```
Install → Splash → Onboarding → Login → KYC (PAN/Aadhaar/Bank)
                                              ↓
                                    Home + Wallet funded
                                              ↓
                         Real trade OR Featured Plan OR Goals
                                              ↓
                              Cashfree payment + compliance
```

---

## 7. Play Store Rejection — Response Template

If rejected again, reply in Play Console **Policy status** with:

> We have updated the app to **paper trading simulation only**. All investment plan screens, payment methods, wallet deposit/withdraw flows, and fixed return marketing have been **removed from this build**. The app does not accept real money. Users practice with virtual funds only. We are not a SEBI-registered broker. Screenshots and store listing have been updated to match.

Attach: screenshot of disclaimer on trade screen.

---

## 8. Action Checklist (Team)

### Before next Play upload

- [ ] `PAPER_ONLY` build flag implemented
- [ ] Featured Plans hidden from Home + routes
- [ ] Wallet deposit/withdraw hidden
- [ ] Payment UI removed from plan screens
- [ ] Onboarding copy fixed (no returns)
- [ ] Paper disclaimer on all trade screens
- [ ] Store listing rewritten (paper simulator)
- [ ] Screenshots replaced (no plans/payments)
- [ ] Play Console Financial Services form updated
- [ ] Internal test on physical device — confirm no payment path reachable

### After license

- [ ] Legal review of Terms
- [ ] Cashfree production go-live checklist
- [ ] KYC production verified
- [ ] Enable real-money features in build
- [ ] Update Play listing + upload license
- [ ] Staged rollout (5% → 100%)

---

## 9. Recommended Timeline

| Week | Phase 1 (Paper launch) |
|------|------------------------|
| 1 | Dev: PAPER_ONLY flag, hide plans/wallet/payments |
| 2 | Copy + disclaimers + QA on device |
| 3 | New store listing + screenshots + internal test track |
| 4 | Production submit → review (3–7 days typical) |

| Month | Phase 2 (After license) |
|-------|-------------------------|
| License pending | Keep paper app live, collect user feedback |
| License received | 2–4 weeks dev + Cashfree prod + compliance |
| Go live | Play update v2.0 + marketing |

---

## 10. Contact & Support

- **Play Console:** https://play.google.com/console  
- **Google Financial Services policy:** Search “Google Play Financial Services” in Play Console Help  
- **SEBI:** Confirm your license category before enabling real trading  

---

*This document is for internal planning. Not legal advice. Consult your compliance advisor before enabling real-money features.*

**Capital BullWave Team — Confidential**
