# Test Forgot Password Endpoints
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Testing Forgot Password API" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://192.168.1.16:3000/api/drivers"
$email = "skprasath@yopmail.com"
$otp = "123456"
$password = "driver12334"

# Test 1: Send OTP
Write-Host "Test 1: Send Forgot Password OTP..." -ForegroundColor Yellow
try {
    $body = @{ email = $email } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/forgot-password/email" -Method POST -Body $body -ContentType "application/json"
    Write-Host "SUCCESS:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 2: Verify OTP
Write-Host "Test 2: Verify OTP..." -ForegroundColor Yellow
try {
    $body = @{ email = $email; otp = $otp } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/forgot-password/verify-otp" -Method POST -Body $body -ContentType "application/json"
    Write-Host "SUCCESS:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 3: Set Password
Write-Host "Test 3: Set New Password..." -ForegroundColor Yellow
try {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/forgot-password/set-password" -Method POST -Body $body -ContentType "application/json"
    Write-Host "SUCCESS:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

# Test 4: Login
Write-Host "Test 4: Login with New Password..." -ForegroundColor Yellow
try {
    $body = @{ email = $email; password = $password } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/login" -Method POST -Body $body -ContentType "application/json"
    Write-Host "SUCCESS:" -ForegroundColor Green
    Write-Host ($response | ConvertTo-Json -Depth 3) -ForegroundColor Green
} catch {
    Write-Host "FAILED:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response: $responseBody" -ForegroundColor Red
    }
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
