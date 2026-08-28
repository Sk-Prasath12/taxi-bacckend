# Downloads cloudflared for Windows (free HTTPS tunnel to your local Docker).
$ErrorActionPreference = "Stop"
$tools = Join-Path (Split-Path -Parent $PSScriptRoot) "tools"
$exe = Join-Path $tools "cloudflared.exe"

if (Test-Path $exe) {
  Write-Host "cloudflared already installed: $exe"
  exit 0
}

New-Item -ItemType Directory -Force -Path $tools | Out-Null
$url = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
Write-Host "Downloading cloudflared..."
Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
Write-Host "Installed: $exe"
