# BullWave — Docker quick start (Windows)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path ".env")) {
    Copy-Item ".env.docker.example" ".env"
    Write-Host "Created .env from .env.docker.example" -ForegroundColor Yellow
    Write-Host "Edit .env and set KOTAK_NEO_ACCESS_TOKEN before continuing." -ForegroundColor Yellow
    notepad .env
}

Write-Host "Starting BullWave (build may take 10+ min on first run)..." -ForegroundColor Green
docker compose up --build
