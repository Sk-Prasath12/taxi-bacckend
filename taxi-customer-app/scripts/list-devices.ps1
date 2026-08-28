# Lists Flutter/Android device IDs for run-on-phone.ps1
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Connected devices (use the id in the second column):"
Write-Host ""
flutter devices
Write-Host ""
Write-Host "Example:"
Write-Host "  .\scripts\run-on-phone.ps1 -DeviceId 7PON7DWCBQ9XTS49"
Write-Host ""
Write-Host "Or use adb directly:"
Write-Host "  adb devices"
