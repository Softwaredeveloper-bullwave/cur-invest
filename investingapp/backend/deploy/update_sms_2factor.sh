#!/usr/bin/env bash
# 1) Free disk  2) Pull latest code  3) Enable 2Factor SMS  4) Migrate + restart
# Run ON THE SERVER:
#   bash ~/cur-invest/investingapp/backend/deploy/update_sms_2factor.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
ENV_FILE="$BACKEND_DIR/.env"
SCRIPT_DIR="$BACKEND_DIR/deploy"

echo "==> Step 1: Free disk space"
if [[ -f "$SCRIPT_DIR/free_disk_space.sh" ]]; then
  bash "$SCRIPT_DIR/free_disk_space.sh"
else
  sudo journalctl --vacuum-size=50M || true
  sudo apt-get clean || true
  pip cache purge 2>/dev/null || true
  df -h /
fi

echo "==> Step 2: Pull latest backend code (includes 2Factor integration)"
cd "$HOME/cur-invest"
git fetch origin
git pull --ff-only origin "$(git branch --show-current)" || git pull --ff-only

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found"
  exit 1
fi

echo "==> Step 3: Backing up .env"
cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d%H%M%S)"

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

echo "==> Step 4: Set 2Factor SMS OTP"
upsert_env SMS_PROVIDER 2factor
upsert_env SMS_OTP_ENABLED True
upsert_env TWOFACTOR_API_KEY '3000b048-9218-11f1-908b-0200cd936042'
upsert_env TWOFACTOR_OTP_TEMPLATE BullwaveClub_OTP
upsert_env TWOFACTOR_SENDER_ID BWCLUB
upsert_env TWOFACTOR_OTP_MODE autogen

echo "==> Step 5: Disable Infobip for OTP"
for key in INFOBIP_API_KEY INFOBIP_BASE_URL INFOBIP_SENDER; do
  if grep -q "^${key}=" "$ENV_FILE"; then
    sed -i "s|^${key}=|# ${key}=|" "$ENV_FILE" || true
  fi
done

echo "==> Step 6: Migrate + check + restart"
cd "$BACKEND_DIR"
source venv/bin/activate
export AI_SKIP_STARTUP_PROBE=1
python manage.py migrate accounts --noinput
python manage.py check_sms || true
sudo systemctl restart bullwave
sleep 3

echo "==> Step 7: Health check"
HEALTH=$(curl -sf "https://api.capitalbullwave.com/health/" || echo '{}')
echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"

echo "$HEALTH" | python3 -c "
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print('WARN: health check failed — check sudo systemctl status bullwave')
    sys.exit(0)
d = json.loads(raw)
sms = d.get('integrations', {}).get('sms_otp', {})
print('sms_otp provider:', sms.get('provider'))
print('sms_otp explicit:', sms.get('explicit', '(old code — run git pull)'))
print('sms_otp twofactor:', sms.get('twofactor', '(old code)'))
if sms.get('provider') == 'infobip':
    print('ERROR: Still on Infobip — verify .env SMS_PROVIDER=2factor and restart')
    sys.exit(1)
if sms.get('twofactor') or sms.get('explicit') == '2factor' or sms.get('provider') == '2factor_autogen':
    print('OK: 2Factor is active')
else:
    print('WARN: Restart done — confirm SMS_PROVIDER in .env if OTP still wrong')
"

echo ""
echo "Test live OTP: cd $BACKEND_DIR && source venv/bin/activate && python manage.py test_2factor_otp YOUR_PHONE"
