#!/usr/bin/env bash
# Local Mac dev: HTTPS tunnel + update .env + start Django for DigiLocker KYC.
# Usage: ./scripts/run_dev_with_digilocker.sh
set -euo pipefail

BACKEND_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$BACKEND_DIR/.env"
PORT="${PORT:-8000}"

upsert_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i '' "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

echo "==> Starting localtunnel on port ${PORT} (background)..."
LT_LOG=$(mktemp)
npx --yes localtunnel --port "$PORT" >"$LT_LOG" 2>&1 &
LT_PID=$!

for i in $(seq 1 30); do
  URL=$(grep -oE 'https://[a-z0-9-]+\.loca\.lt' "$LT_LOG" | head -1 || true)
  if [[ -n "$URL" ]]; then
    break
  fi
  sleep 1
done

if [[ -z "${URL:-}" ]]; then
  echo "Failed to start tunnel. Log:"
  cat "$LT_LOG"
  kill "$LT_PID" 2>/dev/null || true
  exit 1
fi

echo "==> Tunnel URL: $URL"
upsert_env LOCAL_DEV_TUNNEL_URL "$URL"

echo "==> Updated $ENV_FILE"
echo "    LOCAL_DEV_TUNNEL_URL=$URL"
echo ""
echo "Physical device Flutter:"
echo "  flutter run --dart-define=API_BASE_URL=${URL}/api/v1"
echo ""
echo "Simulator (same Mac): keep default or use http://127.0.0.1:8000/api/v1"
echo ""
echo "==> Starting Django (Ctrl+C stops server; tunnel keeps running as PID $LT_PID)"
echo ""

cd "$BACKEND_DIR"
export AI_SKIP_STARTUP_PROBE=1
python3 manage.py rundev --port "$PORT"
