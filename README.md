# Capital BullWave — Web App

Lemonn-style marketing site + **paper trading web app** for Capital BullWave (BullWave Invest).

- **Marketing:** `/` — hero, features, pricing, FAQ (real trading shows **Launching soon**)
- **Paper trading:** `/app` — Google or email OTP → phone → profile → markets, trade, portfolio
- **API:** Same Django backend as Flutter (`/api/v1/`) with `X-BullWave-Client: web`

## Google Sign-In setup

1. [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials  
2. Create **OAuth client ID** → Application type **Web application**  
3. Authorized JavaScript origins:
   - `http://localhost:5173`
   - `http://localhost:5174`
   - your production site origin  
4. Copy Client ID into both:
   - `investingapp/backend/.env` → `GOOGLE_OAUTH_CLIENT_ID=...`
   - `web-app/.env` → `VITE_GOOGLE_CLIENT_ID=...` (same value)  
5. Restart Django + Vite

## Quick start

```bash
# Terminal 1 — Django backend
cd investingapp/backend
python manage.py runserver 0.0.0.0:8000

# Terminal 2 — Web app
cd web-app
cp .env.example .env
npm install
npm run dev
```

Open **http://localhost:5173**

Vite proxies `/api` → `http://127.0.0.1:8000` (see `vite.config.ts`).

## Production

```bash
npm run build
# Serve dist/ via nginx on app.capitalbullwave.com
# Set VITE_API_BASE_URL=https://api.capitalbullwave.com/api/v1
# Add domain to backend CORS_ALLOWED_ORIGINS
```

## Auth flow (website)

1. **Email** — Continue with Google **or** email OTP
2. **Phone** — SMS OTP (2Factor)
3. **Profile** — name (prefilled from Google when available)
4. Paper trading dashboard

APIs:
- `POST /auth/google/` `{ idToken }` → `emailProofToken`
- `POST /auth/web/send-email-otp/` / `verify-email-otp/`
- `POST /auth/send-otp/` / `verify-otp/` (+ `emailProofToken`)

## Stack

- React 19 + TypeScript + Vite 8
- Tailwind CSS 4
- React Router 7
- Lucide icons
