# Requires Administrator. Phones on Wi-Fi need inbound TCP 3000 to reach Docker API.
$ruleName = 'Taxi Backend API TCP 3000'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  Write-Host "Access denied: run this script in an Administrator PowerShell window." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "1. Start menu -> type PowerShell -> right-click -> Run as administrator"
  Write-Host "2. Then run:"
  Write-Host '   cd "D:\taxiuser\taxi_customer_app"'
  Write-Host '   .\scripts\open-firewall-port-3000.ps1'
  Write-Host ""
  Write-Host "Or one line (UAC prompt):"
  Write-Host '   Start-Process powershell -Verb RunAs -ArgumentList ''-NoExit'',''-ExecutionPolicy Bypass'',''-File D:\taxiuser\taxi_customer_app\scripts\open-firewall-port-3000.ps1'''
  exit 1
}

$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
  Write-Host "Firewall rule already exists: $ruleName"
} else {
  try {
    New-NetFirewallRule -DisplayName $ruleName `
      -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow `
      -Profile Private,Domain -ErrorAction Stop | Out-Null
    Write-Host "Created inbound allow rule for TCP 3000 (Private/Domain)."
  } catch {
    Write-Error "Failed to create firewall rule: $_"
    exit 1
  }
}

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.InterfaceAlias -match 'Wi-Fi' -and $_.IPAddress -notlike '169.*' } |
  Select-Object -First 1).IPAddress
if ($ip) {
  Write-Host "Test from phone browser: http://${ip}:3000/api/v1/health"
} else {
  Write-Host "Test from phone browser: http://YOUR_PC_IP:3000/api/v1/health"
}
