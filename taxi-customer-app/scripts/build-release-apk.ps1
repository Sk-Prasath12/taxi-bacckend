# Alias for build-production-apk.ps1
param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl
)

$script = Join-Path $PSScriptRoot "build-production-apk.ps1"
& $script -ApiUrl $ApiUrl
exit $LASTEXITCODE
