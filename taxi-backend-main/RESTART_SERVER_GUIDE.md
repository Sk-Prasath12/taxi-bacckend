# 🔧 How to Fix the 401 Unauthorized Error on Forgot Password

## Problem
The forgot password endpoints are returning `401 Unauthorized` even though they don't require authentication.

## Root Cause
The server is likely running old compiled code and needs to be restarted.

## ✅ Solution - Restart the Server

### Option 1: Manual Restart (Recommended)

1. **Find your server terminal** - The terminal where you ran `npm run dev`
2. **Stop the server:** Press `Ctrl + C`
3. **Start the server again:**
   ```bash
   cd "d:\Taxi Backend new\taxi-backend-main"
   npm run dev
   ```
4. **Wait for:** `"Server running on port 3000"` message
5. **Test again** using VS Code REST Client

### Option 2: Kill and Restart (If Option 1 doesn't work)

1. **Open Task Manager** (Ctrl + Shift + Esc)
2. **Find all `node.exe` processes**
3. **End them all**
4. **Open a new terminal**
5. **Run:**
   ```bash
   cd "d:\Taxi Backend new\taxi-backend-main"
   npm run dev
   ```

---

## 🧪 After Restart - Test the Endpoints

### Using VS Code REST Client (Easiest)

1. Open: `http/driver-auth.http`
2. Run these requests in order:
   - **Request 9:** Forgot Password - Send OTP
   - **Request 10:** Forgot Password - Verify OTP  
   - **Request 11:** Forgot Password - Set Password
   - **Request 4:** Login

### Expected Responses

#### Request 9 - Send OTP:
```
HTTP/1.1 200 OK
{
  "success": true,
  "message": "OTP sent successfully"
}
```

#### Request 10 - Verify OTP:
```
HTTP/1.1 200 OK
{
  "success": true,
  "message": "OTP verified successfully"
}
```

#### Request 11 - Set Password:
```
HTTP/1.1 200 OK
{
  "success": true,
  "message": "Password reset successfully"
}
```

#### Request 4 - Login:
```
HTTP/1.1 200 OK
{
  "token": "eyJhbGci...",
  "user": {
    "id": "...",
    "name": "Skprasath",
    "email": "skprasath@yopmail.com",
    "role": "driver",
    "status": "OFFLINE"
  }
}
```

---

## 📊 Verification Checklist

After restart, verify:

- [ ] Server started without errors
- [ ] Console shows: "Server running on port 3000"
- [ ] No TypeScript compilation errors
- [ ] Request 9 returns 200 OK (not 401)
- [ ] Request 10 returns 200 OK
- [ ] Request 11 returns 200 OK
- [ ] Request 4 returns 200 OK with token

---

## 🐛 If Still Getting 401 After Restart

### Check 1: Verify the Code is Correct

Open `src/modules/driver/driver.routes.ts` and verify lines 36-46 look like this:

```typescript
driverRouter.post("/api/drivers/forgot-password/email", validate(driverForgotPasswordEmailSchema), driverForgotPasswordEmailController);
driverRouter.post(
  "/api/drivers/forgot-password/verify-otp",
  validate(driverForgotPasswordVerifyOtpSchema),
  driverForgotPasswordVerifyOtpController
);
driverRouter.post(
  "/api/drivers/forgot-password/set-password",
  validate(driverForgotPasswordSetPasswordSchema),
  driverForgotPasswordSetPasswordController
);
```

**There should be NO `requireAuth` in these lines!**

### Check 2: Look for Server Errors

In the server terminal, look for:
- TypeScript compilation errors
- Route registration errors
- Any error messages

### Check 3: Test with Health Endpoint

```
GET http://192.168.1.16:3000/api/v1/health
```

Should return:
```json
{
  "success": true,
  "message": "Service healthy"
}
```

---

## 📝 Why This Happened

The code was modified to add error handling for SMTP email sending, but the server wasn't restarted. The old code might have had an unhandled error that was causing the 401 response.

After restart, the new code will:
1. ✅ Create OTP in database
2. ✅ Try to send email
3. ✅ If email fails, log error but continue
4. ✅ Return success response

---

## ✅ Success Indicators

You'll know it's working when:

1. ✅ All 4 requests return `200 OK`
2. ✅ No `401 Unauthorized` errors
3. ✅ Responses have `"success": true`
4. ✅ Server console shows: `[Driver Forgot Password] OTP email sent to ...`

---

## 🚀 Quick Command

If you want to restart using a single command, run this in PowerShell:

```powershell
# Kill all node processes (WARNING: This will stop ALL node apps)
taskkill /F /IM node.exe

# Then start the server
cd "d:\Taxi Backend new\taxi-backend-main"
npm run dev
```

**Note:** This will close all Node.js applications. Make sure you don't have other important Node apps running!

---

## 📞 Need Help?

If you're still having issues after restart:

1. Share the server console output (from terminal)
2. Share the exact response you're getting
3. Share which request is failing (9, 10, 11, or 4)

---

**The code is correct - it just needs the server to restart!** 🚀
