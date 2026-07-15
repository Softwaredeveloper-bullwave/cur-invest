#!/bin/sh
set -e

echo "Waiting for PostgreSQL at ${DB_HOST:-db}:${DB_PORT:-5432}..."
until python -c "
import os, sys
import psycopg2
psycopg2.connect(
    host=os.environ.get('DB_HOST', 'db'),
    port=os.environ.get('DB_PORT', '5432'),
    user=os.environ.get('DB_USER', 'postgres'),
    password=os.environ.get('DB_PASSWORD', 'postgres'),
    dbname=os.environ.get('DB_NAME', 'bullwave_db'),
)
" 2>/dev/null; do
  sleep 1
done
echo "PostgreSQL is ready."

python manage.py migrate --noinput
python manage.py seed_data

if [ -n "${KOTAK_NEO_ACCESS_TOKEN}" ] && [ "${KOTAK_NEO_ACCESS_TOKEN}" != "your-kotak-neo-access-token" ]; then
  echo "Warming Kotak Neo instrument cache..."
  python manage.py warm_kotak_scrip || echo "Kotak warm-up skipped (token may be invalid or API unreachable)."
fi

echo "Starting BullWave API..."
exec "$@"
