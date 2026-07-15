# BullWave Capital — Docker

Run the full app (database, API, Flutter web UI, AI) with one command. No Python, Flutter, or PostgreSQL install needed — only [Docker Desktop](https://www.docker.com/products/docker-desktop/).

## Requirements

- Docker Desktop 4.x+ (Windows / Mac / Linux)
- ~8 GB free disk (Ollama model + images)
- Kotak Neo access token for live stock prices (optional but recommended)

## Quick start

```powershell
# 1. Clone the repo and open the project folder

# 2. Create environment file
copy .env.docker.example .env

# 3. Edit .env — set your Kotak token:
#    KOTAK_NEO_ACCESS_TOKEN=your-real-token

# 4. Start everything (first run builds images + downloads AI model)
docker compose up --build
```

| URL | What |
|-----|------|
| http://localhost:8080 | BullWave app (Flutter web) |
| http://localhost:8000/api/v1/ | REST API |
| http://localhost:8000/admin/ | Django admin |
| http://localhost:8000/health/ | Integration health check |

**Login:** enter any 10-digit phone → OTP prints in the `backend` container logs (`docker compose logs -f backend`). In DEBUG mode the OTP is also returned in the API response as `devOtp`.

## Create admin user

```powershell
docker compose exec backend python manage.py createsuperuser
```

## Stop / reset

```powershell
docker compose down          # stop containers
docker compose down -v       # stop + wipe database & AI model cache
```

## What runs in Docker

| Service | Port | Purpose |
|---------|------|---------|
| `db` | internal | PostgreSQL database |
| `backend` | 8000 | Django REST API |
| `web` | 8080 | Flutter web app (nginx) |
| `ollama` | internal | Local AI (llama3.2:1b) |
| `ollama-pull` | — | One-shot: downloads AI model on first start |

## Optional API keys

All optional for a demo — defaults use console OTP and auto-approve KYC.

| Feature | Env vars |
|---------|----------|
| Live prices (Kotak) | `KOTAK_NEO_ACCESS_TOKEN` |
| Price fallback | `FINNHUB_API_KEY` |
| Cloud AI (instead of Ollama) | `AI_PROVIDER=groq`, `GROQ_API_KEY` |
| Real SMS OTP | `SMS_PROVIDER=msg91` or `twilio` + keys |
| Payments | `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` |

## Troubleshooting

**First start is slow** — Flutter web image build (~5–15 min) + Ollama model download (~1.3 GB).

**`flutter pub get` failed / exit code 1** — usually an old Flutter Docker image. Pull latest code (`git pull`) — the Dockerfile must use `ghcr.io/adrianjagielak/flutter:3.44.1`, not `cirruslabs/flutter:stable`.

**Rebuild web only** — `docker compose build web --no-cache`

**AI not responding** — wait for `ollama-pull` to finish: `docker compose logs ollama-pull`

**Can't login** — check backend logs for OTP: `docker compose logs -f backend`

**Port already in use** — change ports in `docker-compose.yml` (e.g. `"8081:80"` for web).

**Rebuild web after API URL change** — `docker compose build web --no-cache`

## Share with friends

Send them:

1. The git repo link (or zip)
2. Their own `.env` with a Kotak token (or tell them to use Yahoo fallback: `MARKET_DATA_PROVIDER=yahoo` and leave token empty)
3. These three commands:

```powershell
copy .env.docker.example .env
# edit .env
docker compose up --build
```

Then open http://localhost:8080
