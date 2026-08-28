# Build driver app (APK + web) for your Vercel backend, then deploy web for a shareable URL.
param(
  [string]$ApiUrl = "https://taxi-bacckend.vercel.app",
  [switch]$SkipApk,
  [switch]$SkipWebDeploy
)

$ErrorActionPreference = "Stop"
$scripts = Join-Path $PSScriptRoot

Write-Host "API: $ApiUrl"

if (-not $SkipApk) {
  & (Join-Path $scripts "build-release-apk.ps1") -ApiUrl $ApiUrl
  $apk = Join-Path (Split-Path $scripts -Parent) "build\app\outputs\flutter-apk\app-release.apk"
  if (Test-Path $apk) {
    $dlDir = Join-Path (Split-Path $scripts -Parent) "build\web\downloads"
    New-Item -ItemType Directory -Force -Path $dlDir | Out-Null
    Copy-Item $apk (Join-Path $dlDir "taxi-driver.apk") -Force
    Write-Host "APK copy for web download: build\web\downloads\taxi-driver.apk"
  }
}

& (Join-Path $scripts "build-release-web.ps1") -ApiUrl $ApiUrl

if (-not $SkipWebDeploy) {
  $vercel = Get-Command vercel -ErrorAction SilentlyContinue
  if ($vercel) {
    Set-Location (Join-Path $scripts "..\build\web")
    vercel deploy --prod --yes
    Write-Host "Web app deployed — use the URL printed above to share (install PWA or open in browser)."
  } else {
    Write-Host "Vercel CLI not found. Install: npm i -g vercel"
    Write-Host "Then: cd build\web && vercel deploy --prod"
  }
}
