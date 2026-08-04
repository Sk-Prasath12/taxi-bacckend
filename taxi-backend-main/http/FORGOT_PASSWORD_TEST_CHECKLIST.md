# ✅ Forgot Password API - Testing Checklist

## Quick Test (5 Minutes)

### Prerequisites
- [ ] Server is running (`npm run dev`)
- [ ] MongoDB is running
- [ ] You have a driver account in the database

---

## Test Flow

### Step 1: Test Send OTP ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/email
Content-Type: application/json

{
  "email": "skprasath@yopmail.com"
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

**Status:** [ ] Pass  [ ] Fail

**Notes:** _______________________________________________

---

### Step 2: Test Verify OTP ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/verify-otp
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "otp": "123456"
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "OTP verified successfully"
}
```

**Status:** [ ] Pass  [ ] Fail

**Notes:** _______________________________________________

---

### Step 3: Test Set New Password ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/set-password
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "password": "driver12334"
}
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

**Status:** [ ] Pass  [ ] Fail

**Notes:** _______________________________________________

---

### Step 4: Test Login with New Password ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/login
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "password": "driver12334"
}
```

**Expected Response:**
```json
{
  "token": "eyJhbGci...",
  "user": {
    "id": "...",
    "name": "...",
    "email": "skprasath@yopmail.com",
    "role": "driver",
    "status": "OFFLINE"
  }
}
```

**Status:** [ ] Pass  [ ] Fail

**Notes:** _______________________________________________

---

## Error Testing

### Test: Invalid Email ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/email
Content-Type: application/json

{
  "email": "nonexistent@example.com"
}
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Driver not found"
}
```

**Status:** [ ] Pass  [ ] Fail

---

### Test: Invalid OTP ✅

**Request:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/verify-otp
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "otp": "999999"
}
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Invalid OTP"
}
```

**Status:** [ ] Pass  [ ] Fail

---

### Test: Skip OTP Verification ✅

**Try to set password WITHOUT verifying OTP first:**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/set-password
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "password": "newpassword123"
}
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Email is not verified"
}
```

**Status:** [ ] Pass  [ ] Fail

---

## Console Log Checks

### Check Server Logs ✅

After sending OTP, check server console for:

**Success:**
```
[Driver Forgot Password] OTP email sent to skprasath@yopmail.com
```

**Email Failed (but OTP still works):**
```
[Driver Forgot Password] Failed to send OTP email: ...
```

**Status:** [ ] Logs found  [ ] No logs

---

## Automated Test

### Run PowerShell Test Script ✅

```powershell
cd "d:\Taxi Backend new\taxi-backend-main\http"
.\test-driver-api.ps1
```

**Status:** [ ] All tests passed  [ ] Some tests failed

**Failed Tests:** ________________________________________

---

## Final Verification

### Complete Flow Test ✅

1. [ ] Send OTP - Success
2. [ ] Verify OTP - Success
3. [ ] Set Password - Success
4. [ ] Login with New Password - Success
5. [ ] Can access protected endpoints with token

**Overall Status:** [ ] ALL PASS  [ ] SOME FAIL

---

## Issues Found

| # | Issue | Severity | Status |
|---|-------|----------|--------|
| 1 | | High/Med/Low | Open/Fixed |
| 2 | | High/Med/Low | Open/Fixed |
| 3 | | High/Med/Low | Open/Fixed |

---

## Sign-off

**Tested By:** ________________________

**Date:** ________________________

**API Status:** [ ] READY FOR PRODUCTION  [ ] NEEDS FIXES

**Comments:** _______________________________________________

---

## Quick Reference

### Test Credentials
- **Email:** `skprasath@yopmail.com`
- **Password:** `driver12334`
- **Test OTP:** `123456`

### Endpoints
- Send OTP: `POST /api/drivers/forgot-password/email`
- Verify OTP: `POST /api/drivers/forgot-password/verify-otp`
- Set Password: `POST /api/drivers/forgot-password/set-password`
- Login: `POST /api/drivers/login`

### Files
- HTTP Test File: `http/forgot-password-test.http`
- Full Guide: `http/FORGOT_PASSWORD_API_GUIDE.md`
- Test Script: `http/test-driver-api.ps1`
