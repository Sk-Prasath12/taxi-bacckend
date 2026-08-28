# Run taxi driver app on a connected Android phone/emulator.
# Usage:
#   .\run_android.ps1
#   .\run_android.ps1 -Device 7PON7DWCBQ9XTS49
#   .\run_android.ps1 -Release
#   .\run_android.ps1 -Clean

param(
    [string]$Device = "",
    [switch]$Release,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$adb = Join-Path $env:LOCALAPPDATA "Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
    Write-Host "ADB not found at $adb. Install Android SDK platform-tools." -ForegroundColor Red
    exit 1
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    & $adb @Args
}

function Get-LanIp {
    $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.IPAddress -notmatch '^169\.254\.' -and
            $_.PrefixOrigin -ne 'WellKnown'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1 -ExpandProperty IPAddress
    if ($ip) { return $ip }
    return "10.0.2.2"
}

$apiHost = Get-LanIp
Write-Host "API host: $apiHost (backend must run on http://${apiHost}:3000)" -ForegroundColor Cyan

if ($Clean) {
    Write-Host "Cleaning build..." -ForegroundColor Yellow
    flutter clean
}

flutter pub get

Write-Host "Restarting ADB..." -ForegroundColor Yellow
Invoke-Adb kill-server 2>$null
Invoke-Adb start-server | Out-Null

$devices = Invoke-Adb devices | Select-String "device$"
if (-not $devices) {
    Write-Host "No Android device found. Enable USB debugging and reconnect the phone." -ForegroundColor Red
    exit 1
}

$runArgs = @("run", "--dart-define=API_HOST=$apiHost")
if ($Device) {
    $runArgs += @("-d", $Device)
}
if ($Release) {
    $runArgs += "--release"
} else {
    # Avoid VM-service connection failures on some Windows + USB setups
    $runArgs += "--no-fast-start"
}

Write-Host "Starting app..." -ForegroundColor Green
flutter @runArgs
