#!/usr/bin/env bash
# Enable DigiLocker Aadhaar on AWS (Eko requires an HTTPS callback).
# Run ON THE SERVER:
#   bash ~/cur-invest/investingapp/backend/deploy/fix_digilocker_production.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
ENV_FILE="$BACKEND_DIR/.env"
DOMAIN="api.capitalbullwave.com"
HTTPS_URL="https://${DOMAIN}"
ADMIN_EMAIL="${CERTBOT_EMAIL:-bullwaveteam5@gmail.com}"

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
upsert_env BACKEND_PUBLIC_URL "$HTTPS_URL"
upsert_env DIGILOCKER_PUBLIC_URL "$HTTPS_URL"
remove_env LOCAL_DEV_TUNNEL_URL
upsert_env AI_SKIP_STARTUP_PROBE 1

echo "==> Ensure Eko Aadhaar provider"
grep -q '^KYC_AADHAAR_PROVIDER=' "$ENV_FILE" || upsert_env KYC_AADHAAR_PROVIDER eko
grep -q '^KYC_PROVIDER=' "$ENV_FILE" || upsert_env KYC_PROVIDER eko

if [[ ! -f /etc/letsencrypt/live/${DOMAIN}/fullchain.pem ]]; then
  echo "==> No SSL certificate for ${DOMAIN}. Issuing with certbot."
  echo "    DNS A record must already point ${DOMAIN} -> this server (43.204.159.255)."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx
  if ! sudo certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$ADMIN_EMAIL" --redirect; then
    echo ""
    echo "Certbot failed. DigiLocker cannot work over http://43.204.159.255."
    echo "1. At your DNS provider, create:  A  ${DOMAIN}  43.204.159.255"
    echo "2. Open AWS security group ports 80 and 443"
    echo "3. Rerun this script"
    exit 1
  fi
else
  echo "==> SSL certificate already present for ${DOMAIN}"
fi

echo "==> Restart bullwave"
sudo systemctl daemon-reload
sudo systemctl restart bullwave
sleep 3

echo "==> Verify HTTPS"
if curl -sf "${HTTPS_URL}/health/" | head -c 200; then
  echo ""
  echo "OK: ${HTTPS_URL} is up"
else
  echo "WARN: ${HTTPS_URL}/health/ failed. Check nginx and DNS."
  sudo nginx -t || true
fi

echo ""
echo "Done. DigiLocker callback URL is now:"
echo "  ${HTTPS_URL}/api/v1/digilocker/callback/<state>/"
echo ""
echo "In Eko Connect, the DigiLocker redirect URL must allow:"
echo "  ${HTTPS_URL}/api/v1/digilocker/callback/"
echo ""
echo "Retry Aadhaar in the Flutter app."
