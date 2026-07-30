# BullWave Invest — GitHub Push & Run Commands

Use this guide before pushing to GitHub and for daily dev on **backend**, **admin panel**, and **Flutter app**.

---

## What to upload vs what NOT to upload

### Upload to GitHub (safe)

| Path | Why |
|------|-----|
| `investingapp/backend/**/*.py` | Django source code |
| `investingapp/backend/**/migrations/` | Database migrations |
| `investingapp/backend/.env.example` | Template only — **no real keys** |
| `investingapp/backend/requirements.txt` | Python dependencies |
| `investingapp/backend/README.md` | Docs |
| `admin-panel/src/`, `admin-panel/package.json`, etc. | React admin source |
| `admin-panel/.env.example` | Template only |
| `investingapp/bullwavecapital/lib/`, `android/`, `ios/`, `pubspec.yaml` | Flutter source |
| `.gitignore` files | Keeps secrets out of git |

### Never upload (already in `.gitignore`)

| Path | Why |
|------|-----|
| `investingapp/backend/.env` | **Real API keys, DB password, SECRET_KEY** |
| `admin-panel/.env` | Admin API URL + any secrets |
| `investingapp/backend/venv/` | Local Python virtualenv |
| `admin-panel/node_modules/` | npm packages (reinstall with `npm install`) |
| `investingapp/bullwavecapital/build/` | Flutter build output |
| `investingapp/bullwavecapital/.dart_tool/` | Flutter cache |
| `investingapp/backend/media/` | User uploads (KYC selfies, etc.) |
| `investingapp/backend/logs/` | Log files |
| `investingapp/backend/db.sqlite3` | Local DB (production uses PostgreSQL) |
| `*.pem`, `*.key` | SSH / SSL private keys |

### Quick check before every push

```bash
cd /Users/gopal/cur-invest

# Must show .env is ignored (not listed as staged)
git check-ignore -v investingapp/backend/.env admin-panel/.env

# Must NOT list .env, node_modules, venv, build, media
git status

# If anything secret was ever staged by mistake:
git reset HEAD investingapp/backend/.env admin-panel/.env 2>/dev/null
```

---

## GitHub — first time & push

Remote repo: `https://github.com/bullwaveteam5/Investing.git`

### 1. One-time: create `.env` from examples (local only, never commit)

```bash
# Backend
cp investingapp/backend/.env.example investingapp/backend/.env
# Edit with your real keys:
nano investingapp/backend/.env

# Admin panel
cp admin-panel/.env.example admin-panel/.env
# Default local URL is fine for dev:
# VITE_API_BASE_URL=http://127.0.0.1:8000/api/v1/admin-panel
```

### 2. Pre-push checks

```bash
cd /Users/gopal/cur-invest

cd investingapp/backend
python3 manage.py check
python3 manage.py makemigrations --check --dry-run
cd ../..
```

### 3. Stage, commit, push (safe)

```bash
cd /Users/gopal/cur-invest

# Stage everything EXCEPT gitignored files
git add -A

# Verify .env is NOT in the commit
git diff --cached --name-only | grep -E '\.env$' && echo "STOP: .env is staged!" || echo "OK: no .env staged"

# Review what will be committed
git status
git diff --cached --stat

# Commit
git commit -m "Add admin panel, KYC identity review, and backend updates"

# Push to GitHub
git push origin main
```

### 4. If push is rejected (remote has new commits)

```bash
git pull --rebase origin main
git push origin main
```

### 5. Optional: push on a feature branch first (safer)

```bash
git checkout -b feature/kyc-admin-ready
git add -A
git commit -m "Add admin panel and KYC updates"
git push -u origin feature/kyc-admin-ready
# Then open Pull Request on GitHub and merge to main
```

---

## Backend (Django API)

Path: `investingapp/backend/`

### First-time setup (local Mac)

```bash
cd /Users/gopal/cur-invest/investingapp/backend

# Virtual environment
python3 -m venv venv
source venv/bin/activate

# Dependencies
pip install -r requirements.txt

# Env file (if not done yet)
cp .env.example .env
nano .env

# PostgreSQL must be running; create DB if needed:
# CREATE DATABASE bullwave_db;

# Migrations + admin user
python manage.py migrate
python manage.py createsuperuser

# Optional: Eko KYC service activation (after Eko keys in .env)
python manage.py activate_eko_kyc_services
```

### Run backend (development)

```bash
cd /Users/gopal/cur-invest/investingapp/backend
source venv/bin/activate
python manage.py runserver
```

- API root: http://127.0.0.1:8000/
- Health: http://127.0.0.1:8000/health/
- Admin API: http://127.0.0.1:8000/api/v1/admin-panel/

Restart Django after any `.env` change.

### Backend — production (AWS EC2)

```bash
cd /var/www/bullwave/investingapp/backend
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart bullwave
curl https://api.bullwave.in/health/
```

Production `.env` on server (create manually — **never commit**):

```env
DEBUG=False
ADMIN_PANEL_DEV_NO_AUTH=False
SECRET_KEY=<long-random-string>
ALLOWED_HOSTS=api.bullwave.in,<your-ec2-ip>
BACKEND_PUBLIC_URL=https://api.bullwave.in
DB_HOST=<rds-endpoint>
DB_NAME=bullwave_db
DB_USER=...
DB_PASSWORD=...
KYC_AUTO_APPROVE=False
KYC_RELAX_RATE_LIMITS=False
```

---

## Admin panel (React + Vite)

Path: `admin-panel/`

### First-time setup

```bash
cd /Users/gopal/cur-invest/admin-panel

npm install

cp .env.example .env
# Local:
# VITE_API_BASE_URL=http://127.0.0.1:8000/api/v1/admin-panel
```

### Run admin panel (development)

```bash
cd /Users/gopal/cur-invest/admin-panel
npm install   # only needed once or after package.json changes
npm run dev
```

Open the URL Vite prints (usually http://localhost:5173).

Backend must be running. With `DEBUG=True` and `ADMIN_PANEL_DEV_NO_AUTH=True`, login may be skipped locally.

### Admin panel — production build

```bash
cd /Users/gopal/cur-invest/admin-panel

echo 'VITE_API_BASE_URL=https://api.bullwave.in/api/v1/admin-panel' > .env
npm install
npm run build
```

Output is in `admin-panel/dist/` — host on nginx/S3/CloudFront. Do **not** commit `dist/` or `.env`.

---

## Frontend (Flutter app)

Path: `investingapp/bullwavecapital/`

### First-time setup

```bash
cd /Users/gopal/cur-invest/investingapp/bullwavecapital
flutter pub get
```

### Run on emulator / device (local backend)

```bash
cd /Users/gopal/cur-invest/investingapp/bullwavecapital

# Android emulator (backend on same Mac)
flutter run

# Physical phone on same Wi‑Fi (replace with your Mac IP)
flutter run --dart-define=API_HOST=192.168.1.5
```

Ensure Django is running at `http://127.0.0.1:8000` (emulator uses `10.0.2.2` automatically).

### Run Flutter web (DigiLocker testing)

```bash
cd /Users/gopal/cur-invest/investingapp/bullwavecapital
flutter run -d chrome
```

Set in backend `.env`:

```env
APP_WEB_URL=http://localhost:58076
BACKEND_PUBLIC_URL=https://YOUR-NGROK-OR-TUNNEL-URL
```

### Production / Play Store build

```bash
cd /Users/gopal/cur-invest/investingapp/bullwavecapital

flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.bullwave.in/api/v1
```

APK for testing:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://api.bullwave.in/api/v1
```

---

## All three together (daily dev)

Open **3 terminals**:

**Terminal 1 — Backend**

```bash
cd /Users/gopal/cur-invest/investingapp/backend
source venv/bin/activate
python manage.py runserver
```

**Terminal 2 — Admin panel**

```bash
cd /Users/gopal/cur-invest/admin-panel
npm run dev
```

**Terminal 3 — Flutter**

```bash
cd /Users/gopal/cur-invest/investingapp/bullwavecapital
flutter run
# or: flutter run --dart-define=API_HOST=192.168.x.x
```

---

## AWS — clone from GitHub on server

After EC2 is ready:

```bash
sudo mkdir -p /var/www/bullwave
sudo chown ubuntu:ubuntu /var/www/bullwave
cd /var/www/bullwave

git clone https://github.com/bullwaveteam5/Investing.git .
cd investingapp/backend

python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Create production env ON SERVER ONLY
nano .env

python manage.py migrate
python manage.py createsuperuser
python manage.py collectstatic --noinput
```

gunicorn + nginx + HTTPS: see deployment plan for `api.bullwave.in`.

### Update server after new GitHub push

```bash
cd /var/www/bullwave
git pull origin main
cd investingapp/backend
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py collectstatic --noinput
sudo systemctl restart bullwave
```

---

## Summary

| Component | Dev command | Env file (never commit) |
|-----------|-------------|-------------------------|
| Backend | `python manage.py runserver` | `investingapp/backend/.env` |
| Admin | `npm run dev` | `admin-panel/.env` |
| Flutter | `flutter run` | uses `--dart-define` or defaults in code |

**Golden rule:** Only `.env.example` files go to GitHub. Real `.env` stays on your Mac and on the AWS server only.
