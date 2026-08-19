# GitHub & AWS — Kya chahiye Play Store ke liye?

---

## GitHub — Zaroori hai?

**Play Store upload ke liye GitHub zaroori NAHI hai.**

Google Play sirf **AAB file** leta hai — code GitHub pe hona mandatory nahi.

### Phir bhi GitHub kyun use karein?

| Benefit | Explanation |
|---------|-------------|
| Code backup | Laptop kharab ho to code safe |
| Team collaboration | Developers ek saath kaam kar sakein |
| CI/CD | Future mein automatic builds |
| Version history | Purane changes track karna |

### Kya commit karna hai?

**Commit karo:**
- Flutter app code (`investingapp/bullwavecapital/`)
- Backend code (`investingapp/backend/`)
- Admin panel (`admin-panel/`)
- Docs, scripts

**Commit MAT karo (secrets):**
- `android/key.properties`
- `*.jks` / keystore files
- `.env` files (real API keys)
- `investingapp/backend/.env`

Repo mein already `.gitignore` hai in cheezon ke liye.

### GitHub push steps (optional)

```bash
cd /Users/gopal/cur-invest
git status
git add investingapp/ admin-panel/ docs/ .gitignore
git commit -m "Prepare v1.2.0 Play Store learning platform build"
git remote add origin https://github.com/YOUR_ORG/Investing.git   # pehli baar
git push -u origin main
```

**Private repo** rakho agar commercial product hai.

---

## AWS — Zaroori hai?

**Haan — backend API ke liye AWS (ya koi server) chahiye.**

App phone pe chalti hai but **login, OTP, market data, paper trades, KYC** sab **server** se aata hai.

Current production API:
```
https://api.capitalbullwave.com/api/v1
```

Agar ye server **live aur healthy** hai, naya AWS setup abhi zaroori nahi — bas verify karo.

---

## AWS architecture (current / recommended)

```
User Phone (Flutter App)
        │
        ▼ HTTPS
   api.capitalbullwave.com  (Elastic IP / Route53)
        │
        ▼
   Nginx (443) → Gunicorn (Django)
        │
        ├── PostgreSQL (RDS) — users, KYC, trades
        ├── Redis (optional) — caching
        └── S3 (optional) — media / KYC documents
```

### Minimum AWS resources

| Service | Purpose | Region |
|---------|---------|--------|
| EC2 (Ubuntu) | Django + Gunicorn + Nginx | ap-south-1 (Mumbai) |
| RDS PostgreSQL | Database | ap-south-1 |
| Elastic IP | Fixed public IP | ap-south-1 |
| Route53 / DNS | api.capitalbullwave.com | — |
| ACM / Certbot | HTTPS certificate | — |

### Server pe kya chalna chahiye

1. Django backend (`investingapp/backend/`)
2. Gunicorn systemd service
3. Nginx reverse proxy + SSL
4. PostgreSQL (RDS ya local)
5. `.env` with production secrets (Cashfree sandbox, SMS, etc.)

Example deploy scripts already in repo:
```
investingapp/backend/deploy/
  nginx-api.conf.example
  bullwave.service.example
  restart_backend.sh
  fix_production.sh
```

### Health check

Browser ya terminal se:
```bash
curl -s https://api.capitalbullwave.com/api/v1/health/
```

200 OK aana chahiye.

### Admin panel

Admin panel alag deploy hota hai (Vite static site ya EC2 pe):

```bash
cd admin-panel
npm install
VITE_API_BASE_URL=https://api.capitalbullwave.com/api/v1 npm run build
# dist/ folder ko nginx pe host karo
```

Admin panel **Play Store ke liye zaroori nahi** — sirf aapke liye user/KYC manage karne ke liye.

---

## Play Store vs GitHub vs AWS — Summary

| Item | Play Store ke liye? | Kya karta hai |
|------|---------------------|---------------|
| **AAB file** | ✅ Required | App Google pe publish |
| **AWS / Server** | ✅ Required | Login, data, KYC API |
| **GitHub** | ❌ Optional | Code backup & team |
| **Admin panel** | ❌ Optional | Internal ops |
| **Keystore (.jks)** | ✅ Required | App signing — **safe rakho!** |
| **Privacy policy URL** | ✅ Required | Website pe hosted |
| **Play Developer account** | ✅ Required | $25 one-time |

---

## New server bootstrap (if starting fresh)

```bash
# On EC2 Ubuntu
sudo apt update && sudo apt install -y python3-venv nginx certbot python3-certbot-nginx
git clone https://github.com/YOUR_ORG/Investing.git
cd Investing/investingapp/backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # edit with real values
python manage.py migrate
python manage.py collectstatic --noinput
# Configure gunicorn + nginx + certbot (see deploy/ examples)
```

---

## Domain DNS

| Record | Points to |
|--------|-----------|
| `api.capitalbullwave.com` A | EC2 Elastic IP |
| `capitalbullwave.com` | Marketing site / privacy policy |
| `admin.capitalbullwave.com` | Admin panel (optional) |

---

## Before Play Store — server checklist

- [ ] `https://api.capitalbullwave.com/api/v1/health/` returns OK
- [ ] OTP SMS working (2Factor / AWS SNS)
- [ ] KYC APIs working (Cashfree sandbox OK for Phase 1)
- [ ] SSL certificate valid (not expired)
- [ ] `.env` secrets not in git
- [ ] Database backups enabled (RDS automated backups)

---

*Server setup details may vary — use `investingapp/backend/deploy/` scripts as reference.*
