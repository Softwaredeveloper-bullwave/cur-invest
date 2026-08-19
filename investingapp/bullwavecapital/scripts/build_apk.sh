#!/usr/bin/env bash
# Build a release APK for testing on phone/emulator before Play Store upload.
# Play Store requires AAB — use scripts/build_playstore.sh for that.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

API_BASE_URL="${API_BASE_URL:-https://api.capitalbullwave.com/api/v1}"
PAPER_ONLY="${PAPER_ONLY:-true}"

if [[ ! "$API_BASE_URL" == https://* ]]; then
  echo "ERROR: API_BASE_URL must use HTTPS."
  exit 1
fi

KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  echo "NOTE: android/key.properties not found — APK will use debug signing (fine for personal testing)."
fi

echo "Building release APK"
echo "  version: $(grep '^version:' pubspec.yaml | awk '{print $2}')"
echo "  API_BASE_URL=$API_BASE_URL"
echo "  PAPER_ONLY=$PAPER_ONLY"
echo ""

flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=PAPER_ONLY="$PAPER_ONLY"

APK="$ROOT/build/app/outputs/flutter-apk/app-release.apk"
echo ""
echo "APK ready:"
echo "  $APK"
echo ""
echo "Install on a connected Android device:"
echo "  adb install -r \"$APK\""
