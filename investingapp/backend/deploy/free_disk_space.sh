#!/usr/bin/env bash
# Free disk space on EC2 when "No space left on device" blocks migrate/git/gunicorn.
# Run on server: bash ~/cur-invest/investingapp/backend/deploy/free_disk_space.sh
set -euo pipefail

echo "==> Disk BEFORE"
df -h / /tmp /var/tmp /home 2>/dev/null || df -h

echo "==> Largest directories under /home/ubuntu (top 15)"
du -xh /home/ubuntu 2>/dev/null | sort -rh | head -15 || true

echo "==> Journal logs (keep last 50MB)"
sudo journalctl --vacuum-size=50M 2>/dev/null || true

echo "==> APT cache"
sudo apt-get clean 2>/dev/null || true
sudo rm -rf /var/lib/apt/lists/* 2>/dev/null || true

echo "==> Pip cache"
pip cache purge 2>/dev/null || true
rm -rf ~/.cache/pip 2>/dev/null || true

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
if [[ -d "$BACKEND_DIR/venv" ]]; then
  echo "==> Python __pycache__ under backend"
  find "$BACKEND_DIR" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
  find "$BACKEND_DIR" -name '*.pyc' -delete 2>/dev/null || true
fi

echo "==> Old gunicorn/tmp files"
rm -rf "$BACKEND_DIR/run/tmp/"* 2>/dev/null || true
mkdir -p "$BACKEND_DIR/run/tmp" 2>/dev/null || true

echo "==> Truncate large backend log files (>10MB)"
find "$BACKEND_DIR" -maxdepth 3 -name '*.log' -size +10M -exec truncate -s 0 {} \; 2>/dev/null || true

echo "==> Old .env backups (keep latest 3)"
if [[ -d "$BACKEND_DIR" ]]; then
  ls -t "$BACKEND_DIR"/.env.bak.* 2>/dev/null | tail -n +4 | xargs -r rm -f
fi

echo "==> Git gc (compact repo objects)"
if [[ -d "$HOME/cur-invest/.git" ]]; then
  cd "$HOME/cur-invest"
  git gc --prune=now 2>/dev/null || true
fi

echo "==> Docker prune (if installed)"
if command -v docker >/dev/null 2>&1; then
  docker system prune -af --volumes 2>/dev/null || true
fi

echo "==> Disk AFTER"
df -h / /tmp /var/tmp /home 2>/dev/null || df -h

AVAIL=$(df / | awk 'NR==2 {print $4}')
if [[ "${AVAIL:-0}" -lt 50000 ]]; then
  echo ""
  echo "WARN: Still low on disk (<50MB free on /). Manual cleanup may be needed:"
  echo "  du -xh /var/log | sort -rh | head -10"
  echo "  sudo find /var/log -type f -name '*.gz' -delete"
  exit 1
fi

echo ""
echo "OK: Enough free space to run migrate and git pull."
