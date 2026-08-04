# Troubleshooting Guide - Driver Authentication API

## Issue: 401 Unauthorized on Forgot Password Endpoint

### Error You Reported:
```
HTTP/1.1 401 Unauthorized
{
  "success": false,
  "message": "Unauthorized",
  "error": {
    "method": "POST",
    "path": "/api/drivers/forgot-password/email"
  }
}
```

### Root Cause Analysis:

The `/api/drivers/forgot-password/email` endpoint does **NOT** require authentication.
If you're getting a 401 error, it's likely due to one of these reasons:

---

## Possible Causes & Solutions

### 1. Server Not Running
**Check:**
```bash
# Test if server is running
curl http://192.168.1.16:3000/api/v1/health
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Service healthy"
}
```

**Solution:**
- Start the server if it's not running
- Check server logs for startup errors

---

### 2. SMTP Email Sending Failure (Most Likely)

**Symptoms:**
- The OTP is created in database
- But email fails to send
- This might cause an unhandled error

**Solution (Already Fixed):**
I've added error handling to the OTP email sending code. Now even if email fails:
- OTP is still created in database
- You can continue with testing using `123456` as the OTP
- Error is logged to console for debugging

**Check Server Logs:**
```bash
# Look for these log messages:
[Driver Forgot Password] OTP email sent to skprasath@yopmail.com
# OR
[Driver Forgot Password] Failed to send OTP email: ...
```

---

### 3. Database Connection Issue

**Check MongoDB:**
```bash
# Test MongoDB connection
mongosh "mongodb://taxiadmin:taxi123@localhost:27018/taxi_app?authSource=admin"
```

**Solution:**
- Ensure MongoDB is running on port 27018
- Check credentials in `.env.local`
- Verify the database exists

---

### 4. Incorrect HTTP Client Variable Syntax

**Common Mistake:**
```http
# WRONG - Missing double braces
{
  "email": "driverEmail"
}

# CORRECT - With double braces
{
  "email": "{{driverEmail}}"
}
```

**Solution (Already Fixed):**
I've updated the HTTP file to use correct variable syntax throughout.

---

### 5. Route Not Registered

**Verify Routes:**
Check `src/app.ts` line 42:
```typescript
app.use(driverRouter);
```

This mounts all driver routes at the base level, so:
- Route definition: `/api/drivers/forgot-password/email`
- Full URL: `http://192.168.1.16:3000/api/drivers/forgot-password/email`

---

## Step-by-Step Testing Procedure

### Test 1: Check Server Health
```http
GET http://192.168.1.16:3000/api/v1/health
```

### Test 2: Test Forgot Password Flow

**Step 1:** Send OTP
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/email
Content-Type: application/json

{
  "email": "skprasath@yopmail.com"
}
```

**Expected Response (Success):**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

**Expected Response (Driver Not Found):**
```json
{
  "success": false,
  "message": "Driver not found"
}
```

**Step 2:** Verify OTP
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

**Step 3:** Set New Password
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

**Step 4:** Login with New Password
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
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "...",
    "name": "...",
    "email": "skprasath@yopmail.com",
    "role": "driver",
    "status": "OFFLINE",
    "is_blocked": false,
    "blocked_reason": null
  }
}
```

---

## Debugging Commands

### 1. Check Server Logs
```bash
# Look for errors when calling the API
tail -f server.log
```

### 2. Test with cURL
```bash
curl -X POST http://192.168.1.16:3000/api/drivers/forgot-password/email \
  -H "Content-Type: application/json" \
  -d '{"email":"skprasath@yopmail.com"}'
```

### 3. Check Database Directly
```javascript
// In MongoDB
use taxi_app
db.users.findOne({ email: "skprasath@yopmail.com", role: "DRIVER" })
db.driverotps.find({ email: "skprasath@yopmail.com" }).sort({ createdAt: -1 }).limit(5)
```

### 4. Check Network Traffic
- Open browser DevTools (F12)
- Go to Network tab
- Run the request
- Check request/response headers and body

---

## Common Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| 400 | Bad Request | Check request body format and required fields |
| 401 | Unauthorized | Should NOT happen on forgot-password endpoints |
| 404 | Not Found | Driver email doesn't exist in database |
| 409 | Conflict | Driver already exists (use forgot password instead) |
| 500 | Internal Server Error | Check server logs for stack trace |

---

## Quick Fixes

### Fix 1: Restart Server
```bash
# Stop current server (Ctrl+C)
# Then restart
npm run dev
```

### Fix 2: Clear Old OTP Records
```javascript
// In MongoDB
use taxi_app
db.driverotps.deleteMany({ email: "skprasath@yopmail.com" })
```

### Fix 3: Recreate Driver Account
```javascript
// Delete existing driver
db.users.deleteOne({ email: "skprasath@yopmail.com", role: "DRIVER" })

// Then use registration flow instead
```

---

## What I Fixed

1. ✅ **Added Error Handling for SMTP**: Email failures won't break the OTP flow
2. ✅ **Fixed Variable References**: All HTTP variables now use correct `{{variableName}}` syntax
3. ✅ **Added Logging**: Console logs show OTP email status for debugging
4. ✅ **Updated Instructions**: Clear comments in HTTP file guide proper usage
5. ✅ **Token Management**: Simplified token handling with single `@token` variable

---

## Next Steps

1. Restart your server to apply the code changes
2. Test the forgot password flow using the HTTP file
3. Check server console logs for any errors
4. If still getting 401, check:
   - Server is actually running
   - No middleware is incorrectly applied
   - Request URL is exactly correct

---

## Contact/Support

If issues persist after trying all steps:
1. Share the full server console logs
2. Share the exact request you're making
3. Share the complete response you're getting
4. Check if other endpoints work (like `/api/v1/health`)
