#!/usr/bin/env bash
# Build a signed Android App Bundle (.aab) for Google Play Store upload.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ── Required: production API URL (HTTPS) ──
API_BASE_URL="${API_BASE_URL:-https://api.capitalbullwave.com/api/v1}"

if [[ ! "$API_BASE_URL" == https://* ]]; then
  echo "ERROR: API_BASE_URL must use HTTPS for Play Store builds."
  echo "Example: API_BASE_URL=https://api.capitalbullwave.com/api/v1 $0"
  exit 1
fi

KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  echo "WARNING: android/key.properties not found — release will use debug signing."
  echo "Copy android/key.properties.example → android/key.properties and create a keystore."
fi

echo "Building App Bundle with API_BASE_URL=$API_BASE_URL"
flutter pub get
flutter build appbundle --release \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo ""
echo "Upload this file to Google Play Console:"
echo "  build/app/outputs/bundle/release/app-release.aab"
