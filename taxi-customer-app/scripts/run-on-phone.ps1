# Run customer app against Vercel (default). Use -Lan for local Docker only.
param(
  [string]$DeviceId = "",
  [switch]$Lan
)

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$api = "https://taxi-bacckend.vercel.app"
$flutterArgs = @(
  "run",
  "--dart-define=API_BASE_URL=$api/api",
  "--dart-define=SOCKET_BASE_URL=$api",
  "--dart-define=OSRM_BASE_URL=https://router.project-osrm.org",
  "--dart-define=IMAGE_BASE_URL=$api"
)

if ($Lan) {
  & (Join-Path $PSScriptRoot "sync-lan-ip.ps1")
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $hostOnly = ""
  foreach ($line in Get-Content "assets\env\dev.env") {
    if ($line -match '^\s*DEVICE_API_HOST=(.+)$') {
      $hostOnly = $Matches[1].Trim() -replace '/.*', ''
      break
    }
  }
  if (-not $hostOnly) {
    Write-Error "DEVICE_API_HOST missing after sync-lan-ip"
    exit 1
  }
  $flutterArgs = @(
    "run",
    "--dart-define=USE_LAN_BACKEND=true",
    "--dart-define=DEV_API_HOST=$hostOnly"
  )
  Write-Host "LAN Docker: http://${hostOnly}/api"
} else {
  Write-Host "Vercel API: $api/api"
}

if ($DeviceId) {
  $flutterArgs += "-d"
  $flutterArgs += $DeviceId
} else {
  flutter devices
  Write-Host "Re-run with: .\scripts\run-on-phone.ps1 -DeviceId emulator-5554"
}

flutter @flutterArgs
