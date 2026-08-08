#!/usr/bin/env bash
# Start an HTTPS tunnel so Eko DigiLocker can callback to local Django (port 8000).
# Usage: ./scripts/start_digilocker_tunnel.sh
set -euo pipefail

PORT="${1:-8000}"
ENV_FILE="$(cd "$(dirname "$0")/.." && pwd)/.env"

echo "Starting localtunnel on port ${PORT}..."
echo "Keep this terminal open while testing DigiLocker."
echo ""

URL=$(npx --yes localtunnel --port "$PORT" 2>&1 | tee /dev/tty | grep -oE 'https://[a-z0-9-]+\.loca\.lt' | head -1)

if [[ -z "$URL" ]]; then
  echo "Could not read tunnel URL. Run manually: npx localtunnel --port ${PORT}"
  exit 1
fi

echo ""
echo "Add to backend/.env (or update LOCAL_DEV_TUNNEL_URL):"
echo "  LOCAL_DEV_TUNNEL_URL=${URL}"
echo ""
echo "Then restart Django: python manage.py runserver"
echo ""
echo "Physical device: point Flutter at the same tunnel:"
echo "  flutter run --dart-define=API_BASE_URL=${URL}/api/v1"
