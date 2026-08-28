param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl
)

$ApiUrl = $ApiUrl.Trim().TrimEnd('/')
if ($ApiUrl -notmatch '^https?://') { $ApiUrl = "https://$ApiUrl" }
$apiBase = if ($ApiUrl.EndsWith('/api')) { $ApiUrl } else { "$ApiUrl/api" }
$origin = $apiBase -replace '/api$', ''

$root = $PSScriptRoot | Split-Path -Parent
$envFile = Join-Path $root "assets\env\app.env"
@"
APP_ENV=production
API_BASE_URL=$apiBase
SOCKET_BASE_URL=$origin
OSRM_BASE_URL=$origin
IMAGE_BASE_URL=$origin
"@ | Set-Content -Path $envFile -Encoding utf8

Set-Location $root
flutter pub get
flutter build web --release `
  --dart-define=API_BASE_URL=$apiBase `
  --dart-define=SOCKET_BASE_URL=$origin

Write-Host ""
Write-Host "Web build: build\web"
Write-Host "Deploy (Vercel CLI):  vercel deploy build/web --prod"
Write-Host "Or drag build\web folder to Vercel dashboard → New Project → Static Site"
