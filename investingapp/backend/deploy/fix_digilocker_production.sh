#!/usr/bin/env bash
# Fix DigiLocker Aadhaar on AWS production (HTTPS callback required by Eko).
# Run ON THE SERVER:
#   bash ~/cur-invest/investingapp/backend/deploy/fix_digilocker_production.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
ENV_FILE="$BACKEND_DIR/.env"

upsert_env() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  elif grep -q "^# ${key}=" "$ENV_FILE"; then
    sed -i "s|^# ${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '\n%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

remove_env() {
  local key="$1"
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=.*|${key}=|" "$ENV_FILE"
  fi
}

echo "==> Disk space"
df -h / | tail -1

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  exit 1
fi

echo "==> Set production HTTPS callback (DigiLocker + email links)"
upsert_env BACKEND_PUBLIC_URL https://api.capitalbullwave.com
remove_env LOCAL_DEV_TUNNEL_URL
upsert_env AI_SKIP_STARTUP_PROBE 1

echo "==> Ensure Eko Aadhaar provider"
grep -q '^KYC_AADHAAR_PROVIDER=' "$ENV_FILE" || upsert_env KYC_AADHAAR_PROVIDER eko
grep -q '^KYC_PROVIDER=' "$ENV_FILE" || upsert_env KYC_PROVIDER eko

echo "==> Restart bullwave"
sudo systemctl restart bullwave
sleep 3

echo "==> Verify (no public_redirect in logs)"
sudo journalctl -u bullwave -n 20 --no-pager | grep -E 'BACKEND_PUBLIC|admin email' || true

echo ""
echo "Done. DigiLocker callback URL is now:"
echo "  https://api.capitalbullwave.com/api/v1/digilocker/callback/<state>/"
echo ""
echo "Test in Flutter app (default production API — no tunnel needed)."
