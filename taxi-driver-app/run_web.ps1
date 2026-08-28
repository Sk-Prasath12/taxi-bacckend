# Run Taxi Driver app on web - avoids Chrome DWDS debug timeout.
#
# Usage:
#   .\run_web.ps1              # debug + hot reload -> open http://localhost:8080
#   .\run_web.ps1 -Release     # opens Chrome in release mode (no debugger needed)
#   .\run_web.ps1 -Port 8090   # use a different port if 8080 is busy

param(
    [switch]$Release,
    [int]$Port = 8080
)

Set-Location $PSScriptRoot

function Test-PortInUse([int]$p) {
    $conn = Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue
    return $null -ne $conn
}

if (-not $Release) {
    while (Test-PortInUse $Port) {
        Write-Host "Port $Port is in use - trying $($Port + 1)..." -ForegroundColor Yellow
        $Port++
        if ($Port -gt 8099) {
            Write-Host "No free port found. Close other Flutter/web servers and retry." -ForegroundColor Red
            exit 1
        }
    }
}

Write-Host ""
Write-Host "  Do NOT use: flutter run -d chrome" -ForegroundColor Red
Write-Host "  (Chrome debug attach fails on this PC)" -ForegroundColor Red
Write-Host ""

if ($Release) {
    Write-Host "Starting RELEASE on port $Port (Chrome opens automatically)..." -ForegroundColor Green
    flutter run -d chrome --release --web-port=$Port --web-browser-flag="--disable-extensions"
} else {
    Write-Host "Starting DEBUG (web-server) on http://localhost:$Port" -ForegroundColor Green
    Write-Host "Open that URL in Chrome or Edge. Press R here for hot restart." -ForegroundColor Yellow
    Write-Host ""
    flutter run -d web-server --web-hostname=localhost --web-port=$Port
}
