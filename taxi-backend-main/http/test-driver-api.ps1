# Driver API Test Script (PowerShell)
# This script tests all driver authentication endpoints

$BASE_URL = "http://192.168.1.16:3000/api/drivers"
$EMAIL = "skprasath@yopmail.com"
$PASSWORD = "driver12334"
$OTP = "123456"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Driver Authentication API Test Suite" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Check
Write-Host "🔍 Test 1: Checking if server is running..." -ForegroundColor Yellow
try {
    $healthResponse = Invoke-RestMethod -Uri "http://192.168.1.16:3000/api/v1/health" -Method Get
    Write-Host "Response: $($healthResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Server is not running or not accessible!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 2: Forgot Password - Send OTP
Write-Host "📧 Test 2: Forgot Password - Send OTP..." -ForegroundColor Yellow
try {
    $sendOtpBody = @{ email = $EMAIL } | ConvertTo-Json
    $sendOtpResponse = Invoke-RestMethod -Uri "$BASE_URL/forgot-password/email" -Method Post -Body $sendOtpBody -ContentType "application/json"
    Write-Host "Response: $($sendOtpResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to send OTP" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 3: Forgot Password - Verify OTP
Write-Host "✅ Test 3: Forgot Password - Verify OTP..." -ForegroundColor Yellow
try {
    $verifyOtpBody = @{ email = $EMAIL; otp = $OTP } | ConvertTo-Json
    $verifyOtpResponse = Invoke-RestMethod -Uri "$BASE_URL/forgot-password/verify-otp" -Method Post -Body $verifyOtpBody -ContentType "application/json"
    Write-Host "Response: $($verifyOtpResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to verify OTP" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 4: Forgot Password - Set New Password
Write-Host "🔐 Test 4: Forgot Password - Set New Password..." -ForegroundColor Yellow
try {
    $setPasswordBody = @{ email = $EMAIL; password = $PASSWORD } | ConvertTo-Json
    $setPasswordResponse = Invoke-RestMethod -Uri "$BASE_URL/forgot-password/set-password" -Method Post -Body $setPasswordBody -ContentType "application/json"
    Write-Host "Response: $($setPasswordResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to set password" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 5: Login
Write-Host "🔑 Test 5: Login..." -ForegroundColor Yellow
try {
    $loginBody = @{ email = $EMAIL; password = $PASSWORD } | ConvertTo-Json
    $loginResponse = Invoke-RestMethod -Uri "$BASE_URL/login" -Method Post -Body $loginBody -ContentType "application/json"
    Write-Host "Response: $($loginResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
    
    $TOKEN = $loginResponse.token
    if (-not $TOKEN) {
        Write-Host "❌ Failed to extract token from login response" -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Token extracted successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Login failed" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Test 6: Get Profile
Write-Host "👤 Test 6: Get Driver Profile..." -ForegroundColor Yellow
try {
    $headers = @{ Authorization = "Bearer $TOKEN" }
    $profileResponse = Invoke-RestMethod -Uri "$BASE_URL/profile" -Method Get -Headers $headers
    Write-Host "Response: $($profileResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to get profile" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 7: Update Status to ONLINE
Write-Host "🟢 Test 7: Update Status to ONLINE..." -ForegroundColor Yellow
try {
    $headers = @{ 
        Authorization = "Bearer $TOKEN"
        "Content-Type" = "application/json"
    }
    $statusBody = @{ status = "ONLINE" } | ConvertTo-Json
    $statusOnlineResponse = Invoke-RestMethod -Uri "$BASE_URL/status" -Method Patch -Body $statusBody -Headers $headers
    Write-Host "Response: $($statusOnlineResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to update status to ONLINE" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

# Test 8: Update Status to OFFLINE
Write-Host "⚫ Test 8: Update Status to OFFLINE..." -ForegroundColor Yellow
try {
    $headers = @{ 
        Authorization = "Bearer $TOKEN"
        "Content-Type" = "application/json"
    }
    $statusBody = @{ status = "OFFLINE" } | ConvertTo-Json
    $statusOfflineResponse = Invoke-RestMethod -Uri "$BASE_URL/status" -Method Patch -Body $statusBody -Headers $headers
    Write-Host "Response: $($statusOfflineResponse | ConvertTo-Json -Depth 1)" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to update status to OFFLINE" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ All tests completed!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
