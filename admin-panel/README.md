# BullWave React Admin

Staff-only operations website for:

- 24-hour manual bank verification
- PAN and Aadhaar review
- KYC profile visibility
- user, wallet, payment and payout reports
- immutable admin-action audit logs

## First-time setup

Dependencies are already installed. If `node_modules` is removed later:

```bash
cd /Users/gopal/cur-invest/admin-panel
npm install
```

Create an admin login once (only needed when dev auth is disabled):

```bash
cd /Users/gopal/cur-invest/investingapp/backend
python3 manage.py createsuperuser
```

During local development the admin website opens **without login** when
`DEBUG=True` and `ADMIN_PANEL_DEV_NO_AUTH=True` (default). Set
`ADMIN_PANEL_DEV_NO_AUTH=False` in backend `.env` and restart Django to test
staff login before go-live.

Enter the admin phone number and a strong unique password. Do not reuse a
customer password.

## Start locally

### Option A — AWS backend (recommended; no local Django)

1. Ensure EC2 backend is running (`sudo systemctl status bullwave` on the server).
2. Create `admin-panel/.env`:

```env
VITE_API_BASE_URL=https://api.capitalbullwave.com/api/v1/admin-panel
VITE_ADMIN_DEV_NO_AUTH=false
```

3. Start Vite:

```bash
cd /Users/gopal/cur-invest/admin-panel
npm run dev
```

4. Log in at `http://127.0.0.1:5173` with a staff account from EC2 (`python manage.py createsuperuser`).

### Option B — local Django on port 8000

Terminal 1 — Django API:

```bash
cd /Users/gopal/cur-invest/investingapp/backend
python3 manage.py migrate
python3 manage.py runserver 0.0.0.0:8000
```

Terminal 2 — React website:

```bash
cd /Users/gopal/cur-invest/admin-panel
npm run dev -- --host 0.0.0.0
```

Use `.env` with `VITE_API_BASE_URL=/api/v1/admin-panel` (Vite proxies to port 8000).

Open:

- This Mac: `http://127.0.0.1:5173`
- Same Wi-Fi: `http://192.168.1.26:5173`

The frontend automatically calls port `8000` on the same hostname when not using Option A. To use a
different backend, copy `.env.example` to `.env`, set `VITE_API_BASE_URL`, and
restart Vite.

## Saving changes

Vite saves nothing in memory: editing and saving files under `src/`
immediately reloads the browser. Database approvals are saved by Django in
PostgreSQL as soon as the admin presses Approve or Reject.

For a production frontend build:

```bash
npm run build
```

Deploy `dist/` behind HTTPS and set Django `CORS_ALLOWED_ORIGINS` to the exact
admin website origin. Never expose this panel over plain HTTP on the internet.

## Security behavior

- only active `is_staff` users can access APIs
- admin access token expires after 30 minutes
- bank/PAN/Aadhaar decisions are recorded in `AdminActionAudit`
- full Aadhaar is never returned; only its last four digits are shown
- money pages are read-only; no generic wallet-balance editing endpoint exists
# React + TypeScript + Vite

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend enabling type-aware lint rules by installing `oxlint-tsgolint` and editing `.oxlintrc.json`:

```json
{
  "$schema": "./node_modules/oxlint/configuration_schema.json",
  "plugins": ["react", "typescript", "oxc"],
  "options": {
    "typeAware": true
  },
  "rules": {
    "react/rules-of-hooks": "error",
    "react/only-export-components": ["warn", { "allowConstantExport": true }]
  }
}
```

See the [Oxlint rules documentation](https://oxc.rs/docs/guide/usage/linter/rules) for the full list of rules and categories.
