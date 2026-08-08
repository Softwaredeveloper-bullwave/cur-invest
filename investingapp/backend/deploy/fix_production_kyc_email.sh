#!/usr/bin/env bash
# Fix PAN (Eko KYC) + email verification on production EC2.
# Run on server:
#   bash ~/cur-invest/investingapp/backend/deploy/fix_production_kyc_email.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
ENV_FILE="$BACKEND_DIR/.env"
SCRIPT_DIR="$BACKEND_DIR/deploy"

echo "==> Step 1: Free disk (required for migrate/restart)"
if [[ -f "$SCRIPT_DIR/free_disk_space.sh" ]]; then
  bash "$SCRIPT_DIR/free_disk_space.sh" || true
else
  sudo journalctl --vacuum-size=30M 2>/dev/null || true
  sudo apt-get clean 2>/dev/null || true
  df -h /
fi

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

require_env() {
  local key="$1"
  if grep -q "^${key}=.\+" "$ENV_FILE" 2>/dev/null; then
    echo "  OK  $key"
    return 0
  fi
  echo "  MISSING  $key"
  return 1
}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  exit 1
fi

echo "==> Step 2: Public API URL (email links + DigiLocker callbacks)"
upsert_env BACKEND_PUBLIC_URL https://api.capitalbullwave.com

echo "==> Step 3: Email backend (must not stay on console backend)"
upsert_env EMAIL_BACKEND django.core.mail.backends.smtp.EmailBackend
upsert_env EMAIL_PROVIDER smtp
upsert_env EMAIL_USE_TLS True

echo ""
echo "==> Step 4: Verify EKO keys (PAN / bank / UPI / Aadhaar)"
MISSING=0
for key in EKO_DEVELOPER_KEY EKO_ACCESS_KEY EKO_INITIATOR_ID EKO_USER_CODE EKO_BASE_URL; do
  require_env "$key" || MISSING=1
done
grep -q '^KYC_PAN_PROVIDER=' "$ENV_FILE" || upsert_env KYC_PAN_PROVIDER eko
grep -q '^KYC_PROVIDER=' "$ENV_FILE" || upsert_env KYC_PROVIDER eko

echo ""
echo "==> Step 5: Verify email SMTP (registration email OTP)"
for key in EMAIL_HOST EMAIL_PORT EMAIL_HOST_USER EMAIL_HOST_PASSWORD; do
  require_env "$key" || MISSING=1
done
grep -q '^DEFAULT_FROM_EMAIL=' "$ENV_FILE" || upsert_env DEFAULT_FROM_EMAIL admin@capitalbullwave.com

if [[ "$MISSING" -eq 1 ]]; then
  echo ""
  echo "ERROR: Missing keys in $ENV_FILE"
  echo "Copy these blocks from your working local backend/.env:"
  echo "  - EKO_DEVELOPER_KEY, EKO_ACCESS_KEY, EKO_INITIATOR_ID, EKO_USER_CODE"
  echo "  - EKO_ENVIRONMENT=production, EKO_BASE_URL=https://api.eko.in/ekoicici"
  echo "  - EMAIL_HOST=smtp.gmail.com, EMAIL_PORT=587"
  echo "  - EMAIL_HOST_USER=..., EMAIL_HOST_PASSWORD=... (Gmail app password)"
  echo ""
  echo "Then re-run this script and restart: sudo systemctl restart bullwave"
  exit 1
fi

echo ""
echo "==> Step 6: Pull code + restart"
cd "$HOME/cur-invest" && git pull || true
cd "$BACKEND_DIR"
source venv/bin/activate
export AI_SKIP_STARTUP_PROBE=1
python manage.py migrate --noinput 2>/dev/null || true
python manage.py check_email || true
sudo systemctl restart bullwave
sleep 2

echo ""
echo "==> Step 7: Health check"
curl -sf "https://api.capitalbullwave.com/health/" | python3 -m json.tool | grep -E 'eko|email|sms_otp' -A3 || true

echo ""
echo "Done. Test in app:"
echo "  1. Register phone OTP"
echo "  2. Enter email on verify-email screen"
echo "  3. Complete PAN verification"
