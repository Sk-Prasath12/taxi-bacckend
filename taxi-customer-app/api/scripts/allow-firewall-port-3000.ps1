# Allow Windows Firewall inbound TCP port 3000 for backend (run as Administrator if needed)
$port = 3000
$ruleName = "Node Backend Port 3000"

$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Rule '$ruleName' already exists. Port $port should be allowed."
    exit 0
}

New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $port -Action Allow
Write-Host "Added firewall rule: $ruleName (TCP $port). Try the app again."
