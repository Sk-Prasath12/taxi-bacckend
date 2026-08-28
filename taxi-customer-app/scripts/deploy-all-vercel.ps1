# Deploys all Taxi projects that use Vercel + rebuilds Android APKs against production API.
# Run from: D:\taxiuser\taxi_customer_app
$ErrorActionPreference = "Stop"
$ApiUrl = "https://taxi-bacckend.vercel.app"

Write-Host "=== 1) Backend ===" -ForegroundColor Cyan
Set-Location "D:\Taxi Backend new\taxi-backend-main"
vercel --prod --yes

Write-Host ""
Write-Host "=== 2) Admin ===" -ForegroundColor Cyan
Set-Location "D:\Taxi Admin\taxi-admin-react"
vercel --prod --yes

Write-Host ""
Write-Host "=== 3) Customer web (prebuilt) ===" -ForegroundColor Cyan
Set-Location "D:\taxiuser\taxi_customer_app"
flutter build web --release `
  --dart-define=API_BASE_URL=$ApiUrl/api `
  --dart-define=SOCKET_BASE_URL=$ApiUrl `
  --dart-define=OSRM_BASE_URL=https://router.project-osrm.org `
  --dart-define=IMAGE_BASE_URL=$ApiUrl
vercel --prod --yes --archive=tgz

Write-Host ""
Write-Host "=== 4) Driver web (prebuilt) ===" -ForegroundColor Cyan
Set-Location "D:\Taxi deiver\taxi-app"
flutter build web --release `
  --dart-define=API_BASE_URL=$ApiUrl/api `
  --dart-define=SOCKET_BASE_URL=$ApiUrl `
  --dart-define=OSRM_BASE_URL=https://router.project-osrm.org `
  --dart-define=IMAGE_BASE_URL=$ApiUrl
vercel --prod --yes --archive=tgz

Write-Host ""
Write-Host "=== 5) Customer APK ===" -ForegroundColor Cyan
Set-Location "D:\taxiuser\taxi_customer_app"
.\scripts\build-production-apk.ps1 -ApiUrl $ApiUrl

Write-Host ""
Write-Host "=== 6) Driver APK ===" -ForegroundColor Cyan
Set-Location "D:\Taxi deiver\taxi-app"
.\scripts\build-release-apk.ps1 -ApiUrl $ApiUrl

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host "Backend:  $ApiUrl"
Write-Host "Admin:    https://taxi-admin-react.vercel.app"
Write-Host "Customer: https://taxi-customer-app.vercel.app"
Write-Host "Driver:   https://taxi-driver-app.vercel.app (after first deploy)"
Write-Host "APKs:     build\app\outputs\flutter-apk\app-release.apk in each app folder"
