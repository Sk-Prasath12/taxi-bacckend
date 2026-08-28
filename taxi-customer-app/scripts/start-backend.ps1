# Start MongoDB + OSRM + API (run from customer OR backend folder)
$backend = "D:\Taxi Backend new\taxi-backend-main"
if (-not (Test-Path $backend)) {
  Write-Error "Backend not found at $backend"
  exit 1
}
Set-Location $backend
docker compose up -d
Write-Host "Backend: http://localhost:3000/api/v1/health"
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -match 'Wi-Fi' -and $_.IPAddress -notlike '169.*' } | Select-Object -First 1).IPAddress
if ($ip) { Write-Host "Phone (same Wi-Fi): http://${ip}:3000/api/v1/health" }
Write-Host "If phone cannot connect, run as Admin: scripts\open-firewall-port-3000.ps1"
