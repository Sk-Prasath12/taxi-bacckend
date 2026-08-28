# Starts Docker + public tunnel — run this ONCE after every PC restart.
# Keeps MongoDB, OSRM, API, and HTTPS tunnel alive for the release APK.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "=== Taxi Customer App — Server Stack ===" -ForegroundColor Cyan
Write-Host ""

# 1. Docker
Write-Host "[1/3] Docker (MongoDB + OSRM + API)..."
& (Join-Path $PSScriptRoot "start-backend.ps1")

$dockerOk = $false
for ($i = 0; $i -lt 20; $i++) {
  try {
    $h = Invoke-WebRequest -Uri "http://localhost:3000/api/v1/health" -UseBasicParsing -TimeoutSec 3
    if ($h.StatusCode -eq 200) { $dockerOk = $true; break }
  } catch { Start-Sleep -Seconds 2 }
}
if (-not $dockerOk) {
  Write-Host "FAIL: Docker backend not healthy on port 3000" -ForegroundColor Red
  Write-Host "Fix: cd `"D:\Taxi Backend new\taxi-backend-main`" ; docker compose logs app"
  exit 1
}
Write-Host "OK: Docker backend running" -ForegroundColor Green

# 2. Tunnel — reuse if already working
Write-Host ""
Write-Host "[2/3] Public HTTPS tunnel..."
$urlFile = Join-Path $root "public-api-url.txt"
$tunnelOk = $false
if (Test-Path $urlFile) {
  $saved = (Get-Content $urlFile -Raw).Trim()
  if ($saved -and (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    $code = curl.exe -s -o NUL -w "%{http_code}" "$saved/api/v1/health" --connect-timeout 10 2>$null
    if ($code -eq "200") {
      $tunnelOk = $true
      Write-Host "OK: Existing tunnel still works" -ForegroundColor Green
      Write-Host "    $saved"
    }
  }
}

if (-not $tunnelOk) {
  Write-Host "Starting new tunnel (URL may change - rebuild APK if it does)..."
  $publicUrl = & (Join-Path $PSScriptRoot "expose-docker-public.ps1") -StopExisting
  if (-not $publicUrl) { exit 1 }
  Write-Host "OK: New tunnel: $publicUrl" -ForegroundColor Green
  Write-Host ""
  Write-Host "IMPORTANT: URL changed — rebuild APK:" -ForegroundColor Yellow
  Write-Host "  .\scripts\build-production-apk.ps1"
}

# 3. Summary
Write-Host ""
Write-Host "[3/3] Status" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "verify-setup.ps1")
