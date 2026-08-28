# Builds a release APK that works on ANY phone / ANY network (mobile data, Wi-Fi).
# Requires your backend deployed with HTTPS on the public internet.
param(
  [string]$ApiUrl = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Parse-EnvFile {
  param([string]$Path)
  $map = @{}
  if (-not (Test-Path $Path)) { return $map }
  foreach ($line in Get-Content $Path) {
    $t = $line.Trim()
    if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $i = $t.IndexOf("=")
    if ($i -le 0) { continue }
    $k = $t.Substring(0, $i).Trim()
    $v = $t.Substring($i + 1).Trim()
    if ($v.Length -ge 2) {
      $q = $v[0]
      if (($q -eq '"') -or ($q -eq "'")) {
        if ($v.EndsWith($q)) { $v = $v.Substring(1, $v.Length - 2) }
      }
    }
    $map[$k] = $v
  }
  return $map
}

function Normalize-Origin {
  param([string]$Url)
  $u = $Url.Trim().TrimEnd("/")
  if ($u -notmatch "^https?://") { $u = "https://$u" }
  if ($u.EndsWith("/api")) { $u = $u.Substring(0, $u.Length - 4) }
  return $u
}

function Test-PlaceholderUrl {
  param([string]$Url)
  $l = $Url.ToLower()
  if ($l -match "trycloudflare\.com|ngrok\.io|ngrok-free\.app") { return $false }
  return ($l -match "your-public-api-domain|replace_with_your_api|yourdomain\.com|your-production-domain|your-api\.example|api\.example\.com|localhost|192\.168\.|127\.0\.0\.1|^10\.")
}

$envMap = @{}
if (-not $ApiUrl) {
  $urlFile = Join-Path $root "public-api-url.txt"
  if (Test-Path $urlFile) {
    $ApiUrl = (Get-Content $urlFile -Raw).Trim()
  }
}
if (-not $ApiUrl) {
  $prodFile = Join-Path $root ".env.production"
  if (Test-Path $prodFile) {
    $envMap = Parse-EnvFile $prodFile
    if ($envMap["PRODUCTION_API_ORIGIN"]) {
      $ApiUrl = $envMap["PRODUCTION_API_ORIGIN"]
    } elseif ($envMap["API_BASE_URL"]) {
      $ApiUrl = $envMap["API_BASE_URL"]
    }
  }
}

if (-not $ApiUrl) {
  Write-Host ""
  Write-Host "ERROR: No production API URL configured." -ForegroundColor Red
  Write-Host ""
  Write-Host "Option A - one-time file:"
  Write-Host "  1. Copy .env.production.example to .env.production"
  Write-Host "  2. Set PRODUCTION_API_ORIGIN=https://your-real-api.com"
  Write-Host "  3. Run: .\scripts\build-production-apk.ps1"
  Write-Host ""
  Write-Host "Option B - pass URL directly:"
  Write-Host '  .\scripts\build-production-apk.ps1 -ApiUrl "https://your-real-api.com"'
  Write-Host ""
  Write-Host "Option C - Docker on this PC + public tunnel:"
  Write-Host "  .\scripts\setup-universal-apk.ps1"
  exit 1
}

$origin = Normalize-Origin $ApiUrl
$apiBase = "$origin/api"

if ($origin -notmatch "^https://") {
  Write-Error "Production APK requires HTTPS (got: $origin). Deploy backend behind TLS first."
}

if (Test-PlaceholderUrl $origin) {
  Write-Error "Replace placeholder URL with your real public API domain before building."
}

Write-Host "Production API origin: $origin"
Write-Host "Health check:          $apiBase/v1/health"
Write-Host ""

try {
  $healthOk = $false
  if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
    $code = curl.exe -s -o NUL -w "%{http_code}" "$apiBase/v1/health" --connect-timeout 25 2>$null
    $healthOk = ($code -eq "200")
  } else {
    $health = Invoke-WebRequest -Uri "$apiBase/v1/health" -UseBasicParsing -TimeoutSec 15
    $healthOk = ($health.StatusCode -eq 200)
  }
  if ($healthOk) {
    Write-Host "Backend health: HTTP 200" -ForegroundColor Green
  } else {
    throw "not 200"
  }
} catch {
  Write-Warning "Could not reach $apiBase/v1/health from this PC."
  Write-Warning "APK will still build, but login will fail until the server is online."
}

$socket = if ($envMap["SOCKET_BASE_URL"]) { $envMap["SOCKET_BASE_URL"].TrimEnd("/") } else { $origin }
$osrm = if ($envMap["OSRM_BASE_URL"]) { $envMap["OSRM_BASE_URL"].TrimEnd("/") } else { "https://router.project-osrm.org" }
$image = if ($envMap["IMAGE_BASE_URL"]) { $envMap["IMAGE_BASE_URL"].TrimEnd("/") } else { $origin }

$appEnv = Join-Path $root "assets\env\app.env"
@"
APP_ENV=production
API_BASE_URL=$apiBase
SOCKET_BASE_URL=$socket
OSRM_BASE_URL=$osrm
IMAGE_BASE_URL=$image
USE_BACKEND=true
DUMMY_RAZORPAY=false
"@ | Set-Content -Path $appEnv -Encoding ascii

Write-Host "Updated assets/env/app.env"
Write-Host "Building release APK..."
Write-Host ""

flutter clean
flutter pub get
flutter build apk --release `
  --dart-define=API_BASE_URL=$apiBase `
  --dart-define=SOCKET_BASE_URL=$socket `
  --dart-define=OSRM_BASE_URL=$osrm `
  --dart-define=IMAGE_BASE_URL=$image

$apk = Join-Path $root "build\app\outputs\flutter-apk\app-release.apk"
Write-Host ""
Write-Host "SUCCESS - install this APK on any Android phone:" -ForegroundColor Green
Write-Host "  $apk"
Write-Host ""
Write-Host "Register and login work on any device and network (mobile data or WiFi)."
