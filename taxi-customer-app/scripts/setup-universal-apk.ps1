# Full setup: Docker (MongoDB + OSRM + API) -> public HTTPS -> production APK
# Register/login from any phone stores users in MongoDB on this PC (while Docker runs).
param(
  [switch]$SkipBuild,
  [switch]$SkipTunnel
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "=== Step 1/4: Start Docker (MongoDB + OSRM + API) ===" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "start-backend.ps1")

Write-Host ""
Write-Host "Waiting for backend..."
for ($i = 0; $i -lt 30; $i++) {
  try {
    $h = Invoke-WebRequest -Uri "http://localhost:3000/api/v1/health" -UseBasicParsing -TimeoutSec 3
    if ($h.StatusCode -eq 200) { break }
  } catch { Start-Sleep -Seconds 2 }
}

try {
  Invoke-WebRequest -Uri "http://localhost:3000/api/v1/health" -UseBasicParsing -TimeoutSec 5 | Out-Null
  Write-Host "Backend OK: http://localhost:3000/api/v1/health" -ForegroundColor Green
} catch {
  Write-Error "Backend failed to start. Check: docker compose logs -f app"
  exit 1
}

$publicUrl = $null
if (-not $SkipTunnel) {
  Write-Host ""
  Write-Host "=== Step 2/4: Public HTTPS tunnel (any network) ===" -ForegroundColor Cyan
  $publicUrl = & (Join-Path $PSScriptRoot "expose-docker-public.ps1")
} else {
  $urlFile = Join-Path $root "public-api-url.txt"
  if (Test-Path $urlFile) {
    $publicUrl = (Get-Content $urlFile -Raw).Trim()
    Write-Host "Using saved URL: $publicUrl"
  } else {
    Write-Error "No public URL. Run without -SkipTunnel or set public-api-url.txt"
    exit 1
  }
}

if ($SkipBuild) {
  Write-Host ""
  Write-Host "Skipped APK build (-SkipBuild). URL ready for: .\scripts\build-production-apk.ps1"
  exit 0
}

Write-Host ""
Write-Host "=== Step 3/4: Build production APK ===" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "build-production-apk.ps1") -ApiUrl $publicUrl
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== Step 4/4: Done ===" -ForegroundColor Green
Write-Host ""
Write-Host "Install on ANY phone:"
Write-Host "  $root\build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "Requirements while users use the app:"
Write-Host "  - This PC stays ON"
Write-Host "  - Docker running (taxi_app_backend, taxi_app_mongo, taxi_osrm)"
Write-Host "  - cloudflared tunnel running (tools\cloudflared.exe)"
Write-Host ""
Write-Host "Register/login -> saved in MongoDB (Docker container taxi_app_mongo)"
Write-Host ""
Write-Host "For permanent URL (no PC dependency): deploy Docker to a cloud VPS - see DEPLOY_FOR_UNIVERSAL_APK.md"
