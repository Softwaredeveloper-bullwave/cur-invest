#!/bin/sh
set -e
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  cp .env.docker.example .env
  echo "Created .env — edit KOTAK_NEO_ACCESS_TOKEN, then run again."
  exit 1
fi

echo "Starting BullWave (first build may take 10+ minutes)..."
docker compose up --build
