#!/usr/bin/env bash
# Free RDS connection slots so migrate / seed / login can connect.
# Run on EC2:
#   bash ~/cur-invest/investingapp/backend/deploy/free_rds_slots.sh
#
# Eight seconds is not enough: leftover TCP backends can sit on RDS until
# keepalive (~1 min). Do not run manage.py while gunicorn is still up.
set -euo pipefail

echo "==> Stop gunicorn (this is what holds the Postgres slots)"
sudo systemctl stop bullwave || true

echo "==> Kill leftover gunicorn / runserver / stuck manage.py"
pkill -f 'gunicorn.*backend.wsgi' || true
pkill -f 'manage.py runserver' || true
sleep 2
pkill -9 -f 'gunicorn.*backend.wsgi' || true

echo "==> Python / gunicorn still running:"
ps aux | grep -E '[g]unicorn|[m]anage.py runserver' || echo "(none)"

echo "==> Local sockets still talking to Postgres 5432:"
ss -tnp 2>/dev/null | grep 5432 || echo "(none)"

echo "==> Wait 45s for RDS to drop idle backends (keepalive can outlive the process)"
sleep 45

echo ""
echo "RDS slots should be free. Next, in this order:"
echo "  cd ~/cur-invest/investingapp/backend"
echo "  source venv/bin/activate"
echo "  python manage.py seed_education"
echo "  sudo systemctl start bullwave"
echo "  curl -s https://api.capitalbullwave.com/health/ | python3 -m json.tool | grep -A6 database"
echo ""
echo "If seed still fails with rds_reserved: reboot the RDS instance in AWS"
echo "(Modify → failover/reboot), wait until available, then seed again."
echo ""
