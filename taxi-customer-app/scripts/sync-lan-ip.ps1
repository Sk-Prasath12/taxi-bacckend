# Optional: point debug at local Docker LAN IP.
# Default app uses Vercel. Only run this if you pass USE_LAN_BACKEND=true.
param(
  [string]$Ip = ""
)

$root = Split-Path -Parent $PSScriptRoot

if (-not $Ip) {
  $Ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -match 'Wi-Fi|WLAN|Wireless' -and $_.IPAddress -notlike '169.*' } |
    Select-Object -First 1).IPAddress
}

if (-not $Ip) {
  Write-Error "No Wi-Fi IP found. Connect to Wi-Fi or pass -Ip 192.168.x.x"
  exit 1
}

$origin = "http://${Ip}:3000"
$apiBase = "$origin/api"
$osrmUrl = "https://router.project-osrm.org"
$devEnv = Join-Path $root "assets\env\dev.env"

@"
# Auto-generated - debug phone only. Regenerate if IP changes.
DEVICE_API_HOST=${Ip}:3000
API_BASE_URL=$apiBase
SOCKET_BASE_URL=$origin
OSRM_BASE_URL=$osrmUrl
IMAGE_BASE_URL=$origin
"@ | Set-Content -Path $devEnv -Encoding ascii

Write-Host "Updated $devEnv"
Write-Host "  API: $apiBase"
Write-Host ""
Write-Host "Phone test URL (open in phone browser):"
Write-Host "  $apiBase/v1/health"
Write-Host ""
Write-Host "Next: stop flutter run (q), then:"
Write-Host "  .\scripts\run-on-phone.ps1 -DeviceId YOUR_DEVICE_ID"
