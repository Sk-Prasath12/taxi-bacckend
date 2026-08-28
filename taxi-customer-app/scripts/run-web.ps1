# Chrome/Edge debug — uses local Docker at localhost:3000 (not the release APK URL).
param(
  [ValidateSet("edge", "chrome", "web-server")]
  [string]$Device = "chrome"
)

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Web debug -> http://localhost:3000/api (start Docker first)" -ForegroundColor Cyan
Write-Host ""

$flutterArgs = @(
  "run", "-d", $Device,
  "--dart-define=API_BASE_URL=http://localhost:3000/api",
  "--dart-define=SOCKET_BASE_URL=http://localhost:3000"
)
if ($Device -eq "edge" -or $Device -eq "chrome") {
  $flutterArgs += @("--web-browser-flag", "--disable-extensions")
}

flutter @flutterArgs
