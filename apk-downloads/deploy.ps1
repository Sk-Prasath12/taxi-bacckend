# Copy latest Driver + Customer APKs and deploy download page to Vercel.
param(
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$here = $PSScriptRoot
$downloads = Join-Path $here "downloads"
New-Item -ItemType Directory -Force -Path $downloads | Out-Null

$driverApk = "D:\Taxi deiver\taxi-app\build\app\outputs\flutter-apk\app-release.apk"
$customerApk = "D:\taxiuser\taxi_customer_app\build\app\outputs\flutter-apk\app-release.apk"

if (-not (Test-Path $driverApk)) {
  throw "Driver APK not found. Run: cd 'D:\Taxi deiver\taxi-app'; .\scripts\build-release-apk.ps1 -ApiUrl 'https://taxi-bacckend.vercel.app'"
}
if (-not (Test-Path $customerApk)) {
  throw "Customer APK not found. Run: cd 'D:\taxiuser\taxi_customer_app'; .\scripts\build-production-apk.ps1 -ApiUrl 'https://taxi-bacckend.vercel.app'"
}

Copy-Item $driverApk (Join-Path $downloads "taxi-driver.apk") -Force
Copy-Item $customerApk (Join-Path $downloads "taxi-customer.apk") -Force

Write-Host "Copied:"
Write-Host "  taxi-driver.apk   $((Get-Item (Join-Path $downloads 'taxi-driver.apk')).Length) bytes"
Write-Host "  taxi-customer.apk $((Get-Item (Join-Path $downloads 'taxi-customer.apk')).Length) bytes"

Set-Location $here
vercel deploy --prod --yes
Write-Host ""
Write-Host "Share the Production URL above."
Write-Host "Driver:   /downloads/taxi-driver.apk"
Write-Host "Customer: /downloads/taxi-customer.apk"
