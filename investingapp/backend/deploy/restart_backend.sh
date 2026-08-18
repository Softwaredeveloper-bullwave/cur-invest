#!/usr/bin/env bash
# Run on EC2 after .env changes or git pull:
#   bash ~/cur-invest/investingapp/backend/deploy/restart_backend.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
cd "$BACKEND_DIR"

echo "==> Backend dir: $BACKEND_DIR"

if [[ ! -d venv ]]; then
  echo "ERROR: venv not found. Run: python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt"
  exit 1
fi

# shellcheck disable=SC1091
source venv/bin/activate

echo "==> Ensure gunicorn temp directory exists"
mkdir -p "$BACKEND_DIR/run/tmp"
chmod 700 "$BACKEND_DIR/run/tmp"

echo "==> Ensure media directory exists (avatars / uploads)"
mkdir -p "$BACKEND_DIR/media/avatars"
chmod -R u+rwX "$BACKEND_DIR/media"

echo "==> Disk space"
df -h / /tmp "$BACKEND_DIR" 2>/dev/null || df -h

echo "==> Django system check"
python manage.py check

echo "==> SMS config"
python manage.py check_sms || true

echo "==> Restart gunicorn (bullwave)"
sudo systemctl daemon-reload
sudo systemctl restart bullwave
sleep 2

echo "==> Service status"
sudo systemctl status bullwave --no-pager -l || true

echo "==> Local health (gunicorn)"
if curl -sf http://127.0.0.1:8000/health/ | head -c 300; then
  echo ""
  echo "OK: gunicorn responds on 127.0.0.1:8000"
else
  echo ""
  echo "FAIL: gunicorn not responding — recent logs:"
  sudo journalctl -u bullwave -n 40 --no-pager
  exit 1
fi

echo "==> Public health (nginx + SSL)"
if curl -sf https://api.capitalbullwave.com/health/ | head -c 300; then
  echo ""
  echo "OK: public API is up"
else
  echo ""
  echo "WARN: public URL still failing — check nginx:"
  echo "  sudo nginx -t && sudo systemctl status nginx"
  sudo journalctl -u nginx -n 20 --no-pager || true
fi
