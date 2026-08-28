# Exposes local Docker backend (port 3000) to a public HTTPS URL via Cloudflare Tunnel.
# Any phone on mobile data can reach your MongoDB-backed API while Docker runs on this PC.
param(
  [int]$Port = 3000,
  [switch]$StopExisting
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$tools = Join-Path $root "tools"
$exe = Join-Path $tools "cloudflared.exe"
$pidFile = Join-Path $tools "cloudflared.pid"
$logFile = Join-Path $tools "cloudflared.log"
$urlFile = Join-Path $root "public-api-url.txt"

if (-not (Test-Path $exe)) {
  & (Join-Path $PSScriptRoot "install-cloudflared.ps1")
}

if ($StopExisting -and (Test-Path $pidFile)) {
  $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
  if ($oldPid) {
    Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue
  }
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

try {
  $health = Invoke-WebRequest -Uri "http://localhost:$Port/api/v1/health" -UseBasicParsing -TimeoutSec 5
  if ($health.StatusCode -ne 200) { throw "Backend not healthy" }
} catch {
  Write-Error "Docker backend not running on port $Port. Run: .\scripts\start-backend.ps1"
  exit 1
}

if (Test-Path $logFile) { Remove-Item $logFile -Force }
Write-Host "Starting public HTTPS tunnel to http://localhost:$Port ..."
Write-Host "(Keep this PC on and Docker running. Tunnel stops if you close cloudflared.)"
Write-Host ""

$p = Start-Process -FilePath $exe -ArgumentList @(
  "tunnel", "--url", "http://localhost:$Port",
  "--logfile", $logFile,
  "--loglevel", "info"
) -PassThru -WindowStyle Hidden

$p.Id | Set-Content $pidFile

$publicUrl = $null
for ($i = 0; $i -lt 45; $i++) {
  Start-Sleep -Seconds 2
  if (-not (Test-Path $logFile)) { continue }
  $log = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
  if ($log -match '(https://[a-z0-9-]+\.trycloudflare\.com)') {
    $publicUrl = $Matches[1].TrimEnd('/')
    break
  }
}

if (-not $publicUrl) {
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Write-Error "Could not get public URL from cloudflared. Check $logFile"
  exit 1
}

$apiBase = "$publicUrl/api"
Write-Host "Public API URL: $publicUrl"
Write-Host "Health check:   $apiBase/v1/health"

function Test-PublicHealth {
  param([string]$ApiBase)
  $url = "$ApiBase/v1/health"
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $code = curl.exe -s -o NUL -w "%{http_code}" $url --connect-timeout 25 2>$null
    return ($code -eq "200")
  }
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 25
    return ($r.StatusCode -eq 200)
  } catch { return $false }
}

Start-Sleep -Seconds 5
if (Test-PublicHealth -ApiBase $apiBase) {
  Write-Host "Internet health: HTTP 200" -ForegroundColor Green
} else {
  Write-Warning "Open on phone: $apiBase/v1/health (local DNS may be slow on PC)"
}

$publicUrl | Set-Content $urlFile -Encoding ascii

$prodEnv = Join-Path $root ".env.production"
@"
APP_ENV=production
PRODUCTION_API_ORIGIN=$publicUrl
API_BASE_URL=$apiBase
SOCKET_BASE_URL=$publicUrl
OSRM_BASE_URL=https://router.project-osrm.org
IMAGE_BASE_URL=$publicUrl
USE_BACKEND=true
DUMMY_RAZORPAY=false
"@ | Set-Content -Path $prodEnv -Encoding ascii

Write-Host ""
Write-Host "Saved: public-api-url.txt and .env.production"
Write-Host "Build APK: .\scripts\build-production-apk.ps1 -ApiUrl `"$publicUrl`""
Write-Host ""
Write-Host "NOTE: This URL changes when cloudflared restarts. Re-run this script and rebuild APK if tunnel restarts."

return $publicUrl
