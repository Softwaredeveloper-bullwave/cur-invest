#!/usr/bin/env bash
# Fix 502 / gunicorn crash on EC2 ("No usable temporary directory").
# Run on the server:
#   bash ~/cur-invest/investingapp/backend/deploy/fix_production.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
TMP_DIR="$BACKEND_DIR/run/tmp"
SERVICE_SRC="$BACKEND_DIR/deploy/bullwave.service.example"
SERVICE_DST="/etc/systemd/system/bullwave.service"

echo "==> Fix system temp directories"
sudo mkdir -p /tmp /var/tmp /usr/tmp
sudo chmod 1777 /tmp /var/tmp 2>/dev/null || true

echo "==> Create gunicorn worker temp dir"
mkdir -p "$TMP_DIR"
chmod 700 "$TMP_DIR"

echo "==> Disk space"
df -h / /tmp "$BACKEND_DIR" 2>/dev/null || df -h

if [[ ! -d "$BACKEND_DIR/venv" ]]; then
  echo "ERROR: venv missing at $BACKEND_DIR/venv"
  exit 1
fi

echo "==> Install systemd service (TMPDIR + worker-tmp-dir)"
sudo cp "$SERVICE_SRC" "$SERVICE_DST"
sudo systemctl daemon-reload
sudo systemctl enable bullwave
sudo systemctl restart bullwave
sleep 3

echo "==> Service status"
if ! sudo systemctl is-active --quiet bullwave; then
  echo "FAIL: bullwave not running. Logs:"
  sudo journalctl -u bullwave -n 40 --no-pager
  exit 1
fi
sudo systemctl status bullwave --no-pager -l | head -20

echo "==> Local health check"
if curl -sf "http://127.0.0.1:8000/health/" | head -c 400; then
  echo ""
  echo "OK: gunicorn is up on 127.0.0.1:8000"
else
  echo "FAIL: gunicorn not responding"
  sudo journalctl -u bullwave -n 30 --no-pager
  exit 1
fi

echo "==> Public health check"
if curl -sf "https://api.capitalbullwave.com/health/" | head -c 400; then
  echo ""
  echo "OK: https://api.capitalbullwave.com is live"
else
  echo "WARN: public URL still failing — reload nginx:"
  echo "  sudo nginx -t && sudo systemctl reload nginx"
fi

echo ""
echo "Done. Test OTP: python manage.py test_2factor_otp YOUR_PHONE"
echo "Switch prod to 2Factor: bash deploy/update_sms_2factor.sh"
