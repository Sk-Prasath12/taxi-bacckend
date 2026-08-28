# Diagnose why login/register fails — run anytime.
$root = Split-Path -Parent $PSScriptRoot
$urlFile = Join-Path $root "public-api-url.txt"
$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"

Write-Host ""
Write-Host "========== SETUP CHECK ==========" -ForegroundColor Cyan

# Docker
$dockerOk = $false
try {
  $containers = docker ps --format "{{.Names}}" 2>$null
  $need = @("taxi_app_backend", "taxi_app_mongo", "taxi_osrm")
  $missing = $need | Where-Object { $containers -notcontains $_ }
  if ($missing.Count -eq 0) {
    $h = Invoke-WebRequest -Uri "http://localhost:3000/api/v1/health" -UseBasicParsing -TimeoutSec 5
    $dockerOk = ($h.StatusCode -eq 200)
  }
} catch {}

if ($dockerOk) {
  Write-Host "[OK]   Docker: MongoDB + OSRM + API running" -ForegroundColor Green
} else {
  Write-Host "[FAIL] Docker not running or unhealthy" -ForegroundColor Red
  Write-Host "       Fix: .\scripts\start-backend.ps1"
}

# Tunnel
$tunnelOk = $false
$publicUrl = $null
if (Test-Path $urlFile) {
  $publicUrl = (Get-Content $urlFile -Raw).Trim()
}
if ($publicUrl -and (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
  $code = curl.exe -s -o NUL -w "%{http_code}" "$publicUrl/api/v1/health" --connect-timeout 12 2>$null
  $tunnelOk = ($code -eq "200")
}

if ($tunnelOk) {
  Write-Host "[OK]   Public HTTPS: $publicUrl" -ForegroundColor Green
} else {
  Write-Host "[FAIL] Public tunnel offline or URL expired" -ForegroundColor Red
  Write-Host "       Fix: .\scripts\start-stack.ps1"
  if ($publicUrl) {
    Write-Host "       Old URL (dead): $publicUrl"
  }
}

# APK
if (Test-Path $apk) {
  Write-Host "[OK]   Release APK exists" -ForegroundColor Green
  Write-Host "       $apk"
} else {
  Write-Host "[WARN] No release APK built yet" -ForegroundColor Yellow
  Write-Host "       Fix: .\scripts\build-production-apk.ps1"
}

# cloudflared process
$cf = Get-Process -Name cloudflared -ErrorAction SilentlyContinue
if ($cf) {
  Write-Host "[OK]   cloudflared tunnel process running (PID $($cf.Id))" -ForegroundColor Green
} else {
  Write-Host "[FAIL] cloudflared not running" -ForegroundColor Red
  Write-Host "       Fix: .\scripts\expose-docker-public.ps1"
}

Write-Host ""
if ($dockerOk -and $tunnelOk -and (Test-Path $apk)) {
  Write-Host "ALL GOOD - install APK on phones and use register/login." -ForegroundColor Green
} else {
  Write-Host "SOMETHING IS WRONG - fix items marked [FAIL] above." -ForegroundColor Red
}
Write-Host "================================="
Write-Host ""
