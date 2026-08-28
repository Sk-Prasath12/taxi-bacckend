# Expands Chennai Metro operational zone in MongoDB (required for ride booking).
$backend = "D:\Taxi Backend new\taxi-backend-main"
$script = Join-Path $backend "scripts\seed-chennai-zone.js"

if (-not (Test-Path $script)) {
  Write-Error "Missing $script"
  exit 1
}

$mongoRunning = docker ps --format "{{.Names}}" | Select-String -Pattern "taxi_app_mongo" -Quiet
if (-not $mongoRunning) {
  Write-Host "Starting backend stack..."
  Set-Location $backend
  docker compose up -d
  Start-Sleep -Seconds 8
}

Write-Host "Updating Chennai Metro operational zone..."
docker cp $script taxi_app_mongo:/tmp/seed-chennai-zone.js
docker exec taxi_app_mongo mongosh -u taxiadmin -p taxi123 --authenticationDatabase admin taxi_app --file /tmp/seed-chennai-zone.js
if ($LASTEXITCODE -ne 0) {
  Write-Error "Zone update failed. Is Docker running?"
  exit 1
}

Write-Host "Done. Restart backend app container to pick up ride.service changes:"
Write-Host "  cd `"$backend`""
Write-Host "  docker compose restart app"
