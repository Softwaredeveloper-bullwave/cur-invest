# Restart Flutter Chrome against the local CORS proxy (AWS Elastic IP).
# Run from anywhere:
#   powershell -File investingapp/bullwavecapital/scripts/run_chrome.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
if (-not (Test-Path (Join-Path $root "investingapp"))) {
  $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
}
$backend = Join-Path $root "investingapp\backend"
$app = Join-Path $root "investingapp\bullwavecapital"
$proxy = Join-Path $backend "dev_cors_proxy.py"

Write-Host "Starting CORS proxy on http://127.0.0.1:8787 ..."
Start-Process -FilePath "python" -ArgumentList $proxy -WorkingDirectory $backend -WindowStyle Minimized
Start-Sleep -Seconds 1
Set-Location $app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8787/api/v1
