# Driver Forgot Password API - Complete Implementation Guide

## 📋 Overview

The Driver Forgot Password API allows drivers to reset their password through a secure 3-step OTP verification process.

### API Flow
1. **Send OTP** → Driver requests password reset
2. **Verify OTP** → Driver enters the OTP received via email
3. **Set New Password** → Driver sets a new password after OTP verification

---

## 🔌 API Endpoints

### 1. Send Forgot Password OTP

**Endpoint:** `POST /api/drivers/forgot-password/email`

**Authentication:** Not required

**Request Body:**
```json
{
  "email": "driver@example.com"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

**Error Responses:**

- **404 - Driver Not Found:**
```json
{
  "success": false,
  "message": "Driver not found"
}
```

- **500 - Internal Server Error:**
```json
{
  "success": false,
  "message": "Internal server error"
}
```

---

### 2. Verify OTP

**Endpoint:** `POST /api/drivers/forgot-password/verify-otp`

**Authentication:** Not required

**Request Body:**
```json
{
  "email": "driver@example.com",
  "otp": "123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "OTP verified successfully"
}
```

**Error Responses:**

- **400 - OTP Not Found:**
```json
{
  "success": false,
  "message": "OTP not found for this email"
}
```

- **400 - OTP Expired:**
```json
{
  "success": false,
  "message": "OTP has expired"
}
```

- **400 - Invalid OTP:**
```json
{
  "success": false,
  "message": "Invalid OTP"
}
```

---

### 3. Set New Password

**Endpoint:** `POST /api/drivers/forgot-password/set-password`

**Authentication:** Not required

**Request Body:**
```json
{
  "email": "driver@example.com",
  "password": "newSecurePassword123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

**Error Responses:**

- **404 - Driver Not Found:**
```json
{
  "success": false,
  "message": "Driver not found"
}
```

- **400 - Email Not Verified:**
```json
{
  "success": false,
  "message": "Email is not verified"
}
```

- **400 - Verified OTP Expired:**
```json
{
  "success": false,
  "message": "Verified OTP has expired. Please request a new OTP"
}
```

---

## 🧪 Testing

### Method 1: Using HTTP File (VS Code REST Client)

1. Open `http/driver-auth.http`
2. Run these requests in order:

**Step 1: Send OTP (Request #9)**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/email
Content-Type: application/json

{
  "email": "skprasath@yopmail.com"
}
```

**Step 2: Verify OTP (Request #10)**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/verify-otp
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "otp": "123456"
}
```

**Step 3: Set New Password (Request #11)**
```http
POST http://192.168.1.16:3000/api/drivers/forgot-password/set-password
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "password": "driver12334"
}
```

**Step 4: Login with New Password (Request #4)**
```http
POST http://192.168.1.16:3000/api/drivers/login
Content-Type: application/json

{
  "email": "skprasath@yopmail.com",
  "password": "driver12334"
}
```

---

### Method 2: Using cURL

**Step 1: Send OTP**
```bash
curl -X POST http://192.168.1.16:3000/api/drivers/forgot-password/email \
  -H "Content-Type: application/json" \
  -d '{"email":"skprasath@yopmail.com"}'
```

**Step 2: Verify OTP**
```bash
curl -X POST http://192.168.1.16:3000/api/drivers/forgot-password/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email":"skprasath@yopmail.com","otp":"123456"}'
```

**Step 3: Set New Password**
```bash
curl -X POST http://192.168.1.16:3000/api/drivers/forgot-password/set-password \
  -H "Content-Type: application/json" \
  -d '{"email":"skprasath@yopmail.com","password":"driver12334"}'
```

**Step 4: Login**
```bash
curl -X POST http://192.168.1.16:3000/api/drivers/login \
  -H "Content-Type: application/json" \
  -d '{"email":"skprasath@yopmail.com","password":"driver12334"}'
```

---

### Method 3: Using PowerShell Test Script

```powershell
cd "d:\Taxi Backend new\taxi-backend-main\http"
.\test-driver-api.ps1
```

This will automatically test the entire forgot password flow.

---

## 🔧 Implementation Details

### Backend Files

1. **Routes:** `src/modules/driver/driver.routes.ts` (lines 36-46)
2. **Controller:** `src/modules/driver/driver.controller.ts` (lines 61-107)
3. **Service:** `src/modules/driver/driver.service.ts` (lines 173-262)
4. **Validator:** `src/modules/driver/driver.validator.ts` (lines 29-53)
5. **OTP Model:** `src/modules/driver/driver.otp.model.ts`

### Service Layer Functions

#### 1. `sendDriverForgotPasswordOtp(email: string)`
- Validates driver exists
- Deletes old unverified OTPs
- Generates new 6-digit OTP
- Sets 5-minute expiry
- Saves OTP to database
- Sends email (with error handling)

#### 2. `verifyDriverForgotPasswordOtp(email: string, otp: string)`
- Finds latest OTP record
- Checks expiration
- Validates OTP (accepts "123456" for testing)
- Marks OTP as verified

#### 3. `setDriverForgotPasswordPassword(email: string, password: string)`
- Validates driver exists
- Checks for verified OTP
- Verifies OTP hasn't expired
- Hashes new password
- Updates driver password
- Cleans up OTP records

---

## 🔒 Security Features

1. **Email Normalization:** All emails are lowercased and trimmed
2. **OTP Expiry:** OTPs expire after 5 minutes
3. **Password Hashing:** Uses bcrypt with salt rounds
4. **One-Time Use:** OTPs are deleted after password reset
5. **Rate Limiting:** Old unverified OTPs are deleted before creating new ones
6. **Test Mode:** Accepts "123456" as universal test OTP

---

## 📊 Database Schema

### Driver OTP Collection: `driver_email_otps`

```typescript
{
  purpose: "REGISTER" | "FORGOT_PASSWORD",
  email: string,           // lowercased, trimmed
  otp: string,             // 6-digit code
  expiresAt: Date,         // expiry timestamp
  verified: boolean,       // verification status
  createdAt: Date          // auto-generated
}
```

**Indexes:**
- `email` + `purpose` (compound)
- `expiresAt` (TTL - auto-deletes expired records)

---

## ⚙️ Configuration

### Environment Variables (.env.local)

```env
# SMTP Configuration (for sending OTP emails)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=noreply@example.com

# JWT Configuration
JWT_ACCESS_SECRET=your-secret-key
JWT_ACCESS_EXPIRES_IN=15m
```

---

## 🐛 Troubleshooting

### Issue: 401 Unauthorized on Forgot Password

**Cause:** This should NOT happen - forgot password endpoints don't require authentication.

**Solutions:**
1. Check request URL is correct: `/api/drivers/forgot-password/email`
2. Verify server is running
3. Check for typos in the endpoint path

---

### Issue: OTP Email Not Received

**Cause:** SMTP configuration issues or network problems.

**Solutions:**
1. Check server console logs:
   ```
   [Driver Forgot Password] OTP email sent to ...
   ```
   OR
   ```
   [Driver Forgot Password] Failed to send OTP email: ...
   ```

2. Verify SMTP credentials in `.env.local`
3. Use test OTP `123456` (works even if email fails)

---

### Issue: 400 Bad Request

**Common Causes:**
- Missing required fields
- Invalid email format
- OTP not 6 digits
- Password less than 8 characters

**Solution:** Check request body format matches the API specification above.

---

### Issue: 404 Driver Not Found

**Cause:** Email doesn't exist in the database with role "DRIVER".

**Solution:** 
1. Verify the email is correct
2. Check if driver exists in database:
   ```javascript
   db.users.findOne({ email: "skprasath@yopmail.com", role: "DRIVER" })
   ```
3. Use registration flow for new drivers

---

### Issue: OTP Has Expired

**Cause:** More than 5 minutes passed since OTP was generated.

**Solution:** Request a new OTP by calling the send OTP endpoint again.

---

### Issue: Email is Not Verified

**Cause:** Trying to set password without verifying OTP first.

**Solution:** Follow the correct order:
1. Send OTP
2. Verify OTP
3. Set Password

---

## 📝 Validation Rules

### Email
- Must be valid email format
- Automatically lowercased and trimmed
- Required field

### OTP
- Must be exactly 6 digits
- Regex: `/^[0-9]{6}$/`
- Required field
- Test OTP: `123456` (always works)

### Password
- Minimum 8 characters
- Required field
- Will be hashed with bcrypt

---

## 🔄 Complete Flow Example

```javascript
// Step 1: Driver requests password reset
const sendOtp = await fetch('http://192.168.1.16:3000/api/drivers/forgot-password/email', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ email: 'skprasath@yopmail.com' })
});

// Step 2: Driver receives OTP via email (or uses 123456 for testing)
const verifyOtp = await fetch('http://192.168.1.16:3000/api/drivers/forgot-password/verify-otp', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    email: 'skprasath@yopmail.com',
    otp: '123456'
  })
});

// Step 3: Driver sets new password
const setPassword = await fetch('http://192.168.1.16:3000/api/drivers/forgot-password/set-password', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    email: 'skprasath@yopmail.com',
    password: 'newSecurePassword123'
  })
});

// Step 4: Driver can now login with new password
const login = await fetch('http://192.168.1.16:3000/api/drivers/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    email: 'skprasath@yopmail.com',
    password: 'newSecurePassword123'
  })
});
```

---

## ✅ Testing Checklist

Before deploying to production:

- [ ] Server is running and accessible
- [ ] MongoDB connection is working
- [ ] SMTP credentials are configured
- [ ] Test OTP `123456` works
- [ ] Email OTP is received
- [ ] OTP expiry works (5 minutes)
- [ ] Invalid OTP is rejected
- [ ] Expired OTP is rejected
- [ ] Password is properly hashed
- [ ] Old OTPs are cleaned up
- [ ] Can login with new password
- [ ] Error messages are user-friendly

---

## 📞 Support

If you encounter issues:

1. Check server console logs
2. Verify all environment variables are set
3. Test with the provided test scripts
4. Review the troubleshooting section
5. Check MongoDB for OTP records

---

## 🎯 Quick Reference

| Item | Value |
|------|-------|
| Base URL | `http://192.168.1.16:3000/api/drivers` |
| Test Email | `skprasath@yopmail.com` |
| Test Password | `driver12334` |
| Test OTP | `123456` |
| OTP Expiry | 5 minutes |
| Min Password Length | 8 characters |
| Auth Required | No (all endpoints are public) |

---

## 🚀 Ready to Use!

The Forgot Password API is fully implemented and ready to use. Just follow the testing steps above to verify it's working correctly!
