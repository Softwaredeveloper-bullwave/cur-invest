#!/usr/bin/env bash
# Run on EC2: bash ~/cur-invest/investingapp/backend/deploy/diagnose.sh
set -uo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
cd "$BACKEND_DIR"

echo "========== 1. Disk space =========="
df -h / /tmp /var/tmp "$BACKEND_DIR" 2>/dev/null || df -h

echo ""
echo "========== 2. Temp directories =========="
ls -ld /tmp /var/tmp "$BACKEND_DIR/run/tmp" 2>&1 || true

echo ""
echo "========== 3. bullwave service =========="
sudo systemctl status bullwave --no-pager -l 2>&1 | head -25 || true

echo ""
echo "========== 4. Last gunicorn logs =========="
sudo journalctl -u bullwave -n 25 --no-pager 2>&1 || true

echo ""
echo "========== 5. Port 8000 =========="
sudo ss -tlnp | grep 8000 || echo "(nothing listening on 8000)"

echo ""
echo "========== 6. Django import test =========="
if [[ -f venv/bin/activate ]]; then
  # shellcheck disable=SC1091
  source venv/bin/activate
  python manage.py check 2>&1 | tail -5
else
  echo "venv not found"
fi

echo ""
echo "========== 7. Manual gunicorn test (5 sec) =========="
if [[ -f venv/bin/gunicorn ]]; then
  mkdir -p run/tmp
  timeout 5 venv/bin/gunicorn \
    --bind 127.0.0.1:8001 \
    --worker-tmp-dir "$BACKEND_DIR/run/tmp" \
    backend.wsgi:application 2>&1 || true
  echo "(If you see 'Listening at: http://127.0.0.1:8001' above, gunicorn CAN start.)"
else
  echo "gunicorn not installed — run: pip install -r requirements.txt"
fi

echo ""
echo "========== 8. Local curl :8000 =========="
curl -sv --max-time 3 http://127.0.0.1:8000/health/ 2>&1 | tail -8 || true

echo ""
echo "========== FIX =========="
echo "Run: bash $BACKEND_DIR/deploy/fix_production.sh"
