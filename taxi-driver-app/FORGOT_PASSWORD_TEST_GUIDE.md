# Forgot Password Flow - End-to-End Test Guide

## Prerequisites
- Backend API server running on `http://localhost:3000`
- Registered user account with email for testing
- Flutter app running (emulator or physical device)

---

## Test Scenario 1: Complete Happy Path Flow ✅

### Step 1: Navigate to Forgot Password
1. Launch the app
2. On Login page, tap "Forgot Password?" link
3. **Expected**: Navigate to Forgot Password page with email input field

### Step 2: Enter Email & Send OTP
1. Enter a valid registered email (e.g., `test@example.com`)
2. Tap "Continue" button
3. **Expected**: 
   - Loading indicator appears
   - API call: `POST /api/drivers/forgot-password/email`
   - Request body: `{ "email": "test@example.com" }`
   - Success message displayed
   - Navigate to OTP verification page

### Step 3: Verify OTP
1. Check email for 6-digit OTP code
2. Enter all 6 digits in OTP fields
3. Tap "Verify" button
4. **Expected**:
   - Loading indicator appears
   - API call: `POST /api/drivers/forgot-password/verify-otp`
   - Request body: `{ "email": "test@example.com", "otp": "123456" }`
   - Success message: "OTP verified successfully"
   - Navigate to Create New Password page

### Step 4: Reset Password
1. Enter new password (minimum 6 characters)
2. Enter confirm password (must match)
3. Tap "Reset Password" button
4. **Expected**:
   - Loading indicator appears
   - API call: `POST /api/drivers/forgot-password/set-password`
   - Request body: `{ "email": "test@example.com", "password": "newpassword123" }`
   - Success message: "Password reset successfully! Please login."
   - Navigate to Login page

### Step 5: Login with New Password
1. Enter email and new password
2. Tap "Sign In"
3. **Expected**: Successful login and navigate to Dashboard

---

## Test Scenario 2: Error Handling ❌

### Test 2.1: Invalid Email Format
1. Enter invalid email (e.g., `invalidemail`)
2. Tap "Continue"
3. **Expected**: Validation error "Please enter a valid email"

### Test 2.2: Unregistered Email
1. Enter non-existent email (e.g., `nonexistent@example.com`)
2. Tap "Continue"
3. **Expected**: 
   - API error message displayed
   - Example: "Email not found" or "User does not exist"

### Test 2.3: Invalid OTP
1. Enter wrong OTP code (e.g., `000000`)
2. Tap "Verify"
3. **Expected**:
   - Error message: "Invalid OTP. Please try again."
   - Stay on OTP verification page

### Test 2.4: Expired OTP
1. Wait for OTP to expire (typically 5-10 minutes)
2. Enter expired OTP
3. Tap "Verify"
4. **Expected**: Error message about expired OTP

### Test 2.5: Password Too Short
1. Enter password with less than 6 characters
2. Tap "Reset Password"
3. **Expected**: Validation error "Password must be at least 6 characters"

### Test 2.6: Passwords Don't Match
1. Enter different passwords in both fields
2. Tap "Reset Password"
3. **Expected**: Validation error "Passwords do not match"

---

## Test Scenario 3: Resend OTP Functionality 🔄

### Test 3.1: Resend OTP
1. On OTP verification page, wait for cooldown (60 seconds)
2. Tap "Resend again" link
3. **Expected**:
   - API call to resend OTP
   - Success message: "OTP has been resent successfully"
   - OTP fields cleared
   - Cooldown timer restarts (60 seconds)

### Test 3.2: Resend During Cooldown
1. Try to resend before 60 seconds
2. **Expected**: 
   - Message: "Please wait X seconds before resending"
   - Link disabled during cooldown

---

## Test Scenario 4: Network Error Handling 🌐

### Test 4.1: No Internet Connection
1. Disable internet/WiFi
2. Try to send OTP
3. **Expected**: Error message "Network error. Please check your connection."

### Test 4.2: Server Down
1. Stop backend server
2. Try any forgot password operation
3. **Expected**: Network error message displayed

### Test 4.3: Slow Network
1. Simulate slow network (3G)
2. Complete full flow
3. **Expected**: Loading indicators show, no crashes

---

## Test Scenario 5: Edge Cases 🔍

### Test 5.1: Empty Email Field
1. Leave email field empty
2. Tap "Continue"
3. **Expected**: Validation error "Please enter your email"

### Test 5.2: Empty OTP Fields
1. Leave some OTP digits empty
2. Tap "Verify"
3. **Expected**: Error "Please enter complete OTP"

### Test 5.3: Back Navigation
1. Navigate through each step
2. Use back button at any step
3. **Expected**: Proper navigation to previous screen

### Test 5.4: Multiple Rapid Requests
1. Tap "Continue" or "Verify" multiple times quickly
2. **Expected**: Button disabled during loading, no duplicate requests

### Test 5.5: Special Characters in Password
1. Use password with special characters (e.g., `Test@123!`)
2. Complete reset flow
3. **Expected**: Password accepted and can login with it

---

## API Endpoint Testing with curl/Postman

### 1. Send OTP
```bash
curl -X POST http://localhost:3000/api/drivers/forgot-password/email \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'
```

**Expected Response (Success):**
```json
{
  "success": true,
  "message": "OTP sent successfully"
}
```

**Expected Response (Failure):**
```json
{
  "success": false,
  "message": "Email not found"
}
```

### 2. Verify OTP
```bash
curl -X POST http://localhost:3000/api/drivers/forgot-password/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "otp": "123456"}'
```

**Expected Response (Success):**
```json
{
  "success": true,
  "message": "OTP verified successfully"
}
```

**Expected Response (Failure):**
```json
{
  "success": false,
  "message": "Invalid OTP"
}
```

### 3. Reset Password
```bash
curl -X POST http://localhost:3000/api/drivers/forgot-password/set-password \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com", "password": "newpassword123"}'
```

**Expected Response (Success):**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

---

## Test Checklist

- [ ] Happy path flow works completely
- [ ] Email validation works
- [ ] OTP verification works
- [ ] Password reset works
- [ ] Error messages display correctly
- [ ] Resend OTP works with cooldown
- [ ] Network errors handled gracefully
- [ ] Loading indicators show properly
- [ ] Navigation works correctly
- [ ] Can login with new password
- [ ] Password validation works (min 6 chars, match confirm)
- [ ] Back button works on all screens
- [ ] No crashes during testing

---

## Common Issues & Solutions

### Issue: OTP not received
**Solution**: Check backend email configuration, check spam folder

### Issue: API returns 404
**Solution**: Verify backend server is running on port 3000

### Issue: "Network error" appears
**Solution**: Check internet connection, verify API URL in auth_service.dart

### Issue: App crashes during flow
**Solution**: Check Flutter console for errors, verify all imports

---

## Success Criteria

✅ All happy path scenarios work without errors  
✅ All error scenarios display appropriate messages  
✅ No app crashes during any test  
✅ Proper loading states shown  
✅ Navigation flow is smooth  
✅ New password allows successful login  

---

## Next Steps After Testing

1. Document any bugs found
2. Test with multiple user accounts
3. Test on different devices/screen sizes
4. Test with different network conditions
5. Verify backend logs for proper API calls
