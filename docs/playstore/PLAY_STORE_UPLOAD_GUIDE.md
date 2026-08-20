# Capital BullWave — Play Store Upload Guide (Phase 1)

**Version:** 1.2.1+8  
**Package name (Android):** `com.bullwave.bullwave_learn`  
**Mode:** Market Learning + Paper Trading Simulator (no license required)  
**Production API:** https://api.capitalbullwave.com/api/v1  

> **Note:** This is a **new Play Store app** — different from `com.bullwave.bullwave_invest`. Create a **new app** in Play Console with this package name.

---

## Kya upload karna hai?

| File | Kab use karein |
|------|----------------|
| **APK** (`app-release.apk`) | Apne phone/laptop pe test karne ke liye |
| **AAB** (`app-release.aab`) | Google Play Console pe **official upload** ke liye (required) |

Google Play **APK accept nahi karta** naye apps ke liye — sirf **AAB (Android App Bundle)** chahiye. APK sirf aapke testing ke liye hai.

---

## Step 1 — Pehle test APK banao

```bash
cd investingapp/bullwavecapital
chmod +x scripts/build_apk.sh
./scripts/build_apk.sh
```

Output:
```
build/app/outputs/flutter-apk/app-release.apk
```

**Phone pe install:**
1. USB se phone connect karo, USB debugging ON
2. `adb install -r build/app/outputs/flutter-apk/app-release.apk`

**Ya** APK ko WhatsApp/Drive se phone pe bhej kar manually install karo (Unknown sources allow karna padega).

---

## Step 2 — Release signing keystore (ek baar)

Play Store ke liye **same keystore** hamesha use karna — khona mat.

```bash
keytool -genkey -v -keystore ~/bullwave-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Phir:
```bash
cp android/key.properties.example android/key.properties
# key.properties mein apna password aur keystore path daalo
```

`android/key.properties` **git mein commit mat karo** — already gitignored hai.

---

## Step 3 — Play Store ke liye AAB banao

```bash
cd investingapp/bullwavecapital
chmod +x scripts/build_playstore.sh
./scripts/build_playstore.sh
```

Output:
```
build/app/outputs/bundle/release/app-release.aab
```

Ye file Play Console pe upload karni hai.

---

## Step 4 — Google Play Console setup

1. **Account:** https://play.google.com/console  
   - One-time developer fee: ~$25 USD  
   - Company ya individual account banao

2. **Create app** (new listing — do not reuse old `com.bullwave.bullwave_invest` app)
   - App name: `Capital BullWave Learn`
   - Package will be read from AAB: **`com.bullwave.bullwave_learn`**

3. **Store listing** — copy text from `docs/playstore/PLAY_STORE_LISTING.md`

4. **App category**
   - Category: **Finance** ya **Education** (simulation/education fit kare)
   - Tags: paper trading, market learning, stock simulator

5. **Financial Services declaration**
   - **No real-money features** in this build
   - App is simulation / educational only
   - Do NOT declare payment processing

6. **Data safety form** — `docs/playstore/DATA_SAFETY_CHECKLIST.md` follow karo

7. **Content rating** — questionnaire honestly bhariye (18+, finance)

8. **Privacy policy URL** (required):
   - https://capitalbullwave.com/privacy

9. **Target audience** — 18+

---

## Step 5 — Upload & release tracks

Recommended order:

```
Internal testing (aap + team)
    ↓
Closed testing (10+ testers, optional 14 days)
    ↓
Production
```

1. Play Console → **Testing → Internal testing → Create release**
2. Upload `app-release.aab`
3. Release notes likho (example below)
4. Review → Start rollout

**Release notes (v1.2.1):**
```
• Market learning & paper trading simulator
• Live NSE/BSE charts and watchlists
• Virtual practice wallet — no real money
• Identity verification for secure accounts
• Educational content and calculators
```

---

## Step 6 — Screenshots (important!)

Google **installed app** aur screenshots match karta hai.

**Include:**
- Onboarding / login
- Home with paper trading disclaimer
- Markets + Paper Trading screen
- Practice Wallet (virtual balance)
- Charts / watchlist

**Do NOT include:**
- Featured Plans (Premier/Crown)
- Add Money / UPI payment screens
- Fixed return % marketing

Minimum: 2 phone screenshots (1080×1920 recommended).

---

## Agar reject ho jaye?

Play Console → **Policy status** → exact policy name padho.

Common fix for finance apps:
> We updated the app to **market learning and paper trading simulation only**. All investment plans, payment flows, wallet deposits, and fixed-return marketing are **removed**. Users practice with virtual funds only. We are **not a SEBI-registered broker**.

Screenshot attach karo: Paper Trading screen par disclaimer dikhta ho.

---

## Build flags reference

| Flag | Play Store value | Meaning |
|------|------------------|---------|
| `PAPER_ONLY=true` | **Yes (default)** | Hides real money, plans, deposits |
| `API_BASE_URL` | `https://api.capitalbullwave.com/api/v1` | Production backend |

Phase 2 (license ke baad):
```bash
PAPER_ONLY=false ./scripts/build_playstore.sh
```

---

## Quick checklist before upload

- [ ] `./scripts/build_apk.sh` — phone pe test kiya
- [ ] Login → OTP → Email → Profile → PAN → Aadhaar → Bank → Home ka flow test kiya
- [ ] Featured Plans / Add Money / Copy Trade **nahi** dikh rahe
- [ ] Paper Trading khulta hai
- [ ] `android/key.properties` set hai (signed AAB)
- [ ] Store listing text updated (no % returns)
- [ ] Privacy policy URL live hai
- [ ] Screenshots sirf paper/learning features dikhate hain

---

## Support contacts (Play Console mein daalo)

- Email: admin@capitalbullwave.com  
- Website: https://capitalbullwave.com  

---

*Internal guide — not legal advice. Consult compliance before enabling real-money features.*
