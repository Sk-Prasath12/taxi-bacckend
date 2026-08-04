#!/bin/bash

# Driver API Test Script
# This script tests all driver authentication endpoints

BASE_URL="http://192.168.1.16:3000/api/drivers"
EMAIL="skprasath@yopmail.com"
PASSWORD="driver12334"
OTP="123456"

echo "========================================="
echo "Driver Authentication API Test Suite"
echo "========================================="
echo ""

# Test 1: Health Check
echo "🔍 Test 1: Checking if server is running..."
HEALTH_RESPONSE=$(curl -s http://192.168.1.16:3000/api/v1/health)
echo "Response: $HEALTH_RESPONSE"
echo ""

# Test 2: Forgot Password - Send OTP
echo "📧 Test 2: Forgot Password - Send OTP..."
SEND_OTP_RESPONSE=$(curl -s -X POST "$BASE_URL/forgot-password/email" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\"}")
echo "Response: $SEND_OTP_RESPONSE"
echo ""

# Test 3: Forgot Password - Verify OTP
echo "✅ Test 3: Forgot Password - Verify OTP..."
VERIFY_OTP_RESPONSE=$(curl -s -X POST "$BASE_URL/forgot-password/verify-otp" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"otp\":\"$OTP\"}")
echo "Response: $VERIFY_OTP_RESPONSE"
echo ""

# Test 4: Forgot Password - Set New Password
echo "🔐 Test 4: Forgot Password - Set New Password..."
SET_PASSWORD_RESPONSE=$(curl -s -X POST "$BASE_URL/forgot-password/set-password" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "Response: $SET_PASSWORD_RESPONSE"
echo ""

# Test 5: Login
echo "🔑 Test 5: Login..."
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")
echo "Response: $LOGIN_RESPONSE"
echo ""

# Extract token from login response
TOKEN=$(echo $LOGIN_RESPONSE | grep -o '"token":"[^"]*' | grep -o '[^"]*$')

if [ -z "$TOKEN" ]; then
  echo "❌ Failed to extract token from login response"
  echo "Please check the login response above"
  exit 1
fi

echo "✅ Token extracted successfully"
echo ""

# Test 6: Get Profile
echo "👤 Test 6: Get Driver Profile..."
PROFILE_RESPONSE=$(curl -s -X GET "$BASE_URL/profile" \
  -H "Authorization: Bearer $TOKEN")
echo "Response: $PROFILE_RESPONSE"
echo ""

# Test 7: Update Status to ONLINE
echo "🟢 Test 7: Update Status to ONLINE..."
STATUS_ONLINE_RESPONSE=$(curl -s -X PATCH "$BASE_URL/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"status\":\"ONLINE\"}")
echo "Response: $STATUS_ONLINE_RESPONSE"
echo ""

# Test 8: Update Status to OFFLINE
echo "⚫ Test 8: Update Status to OFFLINE..."
STATUS_OFFLINE_RESPONSE=$(curl -s -X PATCH "$BASE_URL/status" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"status\":\"OFFLINE\"}")
echo "Response: $STATUS_OFFLINE_RESPONSE"
echo ""

echo "========================================="
echo "✅ All tests completed!"
echo "========================================="
