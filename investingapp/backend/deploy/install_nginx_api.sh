#!/usr/bin/env bash
# Install nginx vhosts for the Elastic IP (HTTP) and api.capitalbullwave.com (HTTPS).
# Run ON THE SERVER:
#   bash ~/cur-invest/investingapp/backend/deploy/install_nginx_api.sh
set -euo pipefail

BACKEND_DIR="${BACKEND_DIR:-$HOME/cur-invest/investingapp/backend}"
SRC="$BACKEND_DIR/deploy/nginx-api.conf.example"
DEST="/etc/nginx/sites-available/bullwave-api"
DOMAIN="api.capitalbullwave.com"
CERT="/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: missing $SRC"
  exit 1
fi

echo "==> Install nginx site with server_name ${DOMAIN}"
sudo mkdir -p /var/www/html
sudo cp "$SRC" "$DEST"
sudo ln -sfn "$DEST" /etc/nginx/sites-enabled/bullwave-api
sudo rm -f /etc/nginx/sites-enabled/default

if [[ ! -f "$CERT" ]]; then
  echo "==> Certificate not present yet; keep HTTP-only for ${DOMAIN}"
  sudo python3 - << 'PY'
from pathlib import Path
path = Path("/etc/nginx/sites-available/bullwave-api")
text = path.read_text()
start = text.find("server {\n    listen 443")
if start != -1:
    # Drop the TLS server until certs exist, and proxy HTTP instead of 301.
    text = text[:start].rstrip() + "\n"
text = text.replace(
    "    location / {\n        return 301 https://$host$request_uri;\n    }",
    """    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_pass http://bullwave_gunicorn;
    }""",
    1,
)
path.write_text(text)
print("HTTP-only nginx config written")
PY
fi

echo "==> nginx -t"
sudo nginx -t
sudo systemctl reload nginx
echo "OK: nginx reloaded"
