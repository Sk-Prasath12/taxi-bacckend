# Driver Authentication API - Usage Guide

## Overview
This file contains all driver authentication endpoints with proper variable handling.

## Variables Configuration
At the top of the file, you'll find these variables:
- `@baseUrl` - The base URL for all driver endpoints
- `@driverEmail` - Test email address
- `@driverPassword` - Test password
- `@driverOtp` - Test OTP (123456 works for testing)
- `@token` - Will be populated after login

## How to Use

### Step-by-Step Flow:

#### For NEW Driver Registration:
1. Run "1) Send OTP" - Creates OTP session
2. Run "2) Verify OTP" - Use the OTP from email OR use 123456 (test OTP)
3. Run "3) Set Password" - Sets password for the new account
4. Run "4) Login" - Logs in and get token
5. Copy the token from login response
6. Update `@token` variable with the received token
7. Now you can use requests 5-8 (Profile, Status updates)

#### For EXISTING Driver (Forgot Password):
1. Run "9) Forgot Password - Send OTP" - Creates OTP session
2. Run "10) Forgot Password - Verify OTP" - Use OTP from email OR 123456
3. Run "11) Forgot Password - Set New Password" - Sets new password
4. Run "4) Login" - Login with new password
5. Copy the token from login response
6. Update `@token` variable with the received token

## Important Notes

### Token Management:
After running "4) Login", you'll get a response like:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": { ... }
}
```

Copy the token value and update the `@token` variable at the top:
```
@token = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Testing OTP:
- The system accepts `123456` as a universal test OTP
- In production, you would use the actual OTP sent via email
- For testing purposes, you can always use `123456`

### Common Issues:

#### 401 Unauthorized Error:
- **Cause**: Missing or invalid token
- **Solution**: Run login request first, then update `@token` variable

#### 400 Bad Request on Verify OTP:
- **Cause**: OTP session doesn't exist
- **Solution**: Always run "Send OTP" before "Verify OTP"

#### 409 Conflict:
- **Cause**: Driver already exists
- **Solution**: Use forgot password flow instead of registration

#### 404 Not Found:
- **Cause**: Email doesn't exist in database
- **Solution**: Use registration flow for new emails

## API Endpoints Summary

| # | Endpoint | Method | Auth Required | Description |
|---|----------|--------|---------------|-------------|
| 1 | /register/email | POST | No | Send registration OTP |
| 2 | /register/verify-otp | POST | No | Verify registration OTP |
| 3 | /register/set-password | POST | No | Set password after verification |
| 4 | /login | POST | No | Login with email/password |
| 5 | /profile | GET | Yes | Get driver profile |
| 6 | /status | PATCH | Yes | Set status to ONLINE |
| 7 | /status | PATCH | Yes | Set status to BUSY |
| 8 | /status | PATCH | Yes | Set status to OFFLINE |
| 9 | /forgot-password/email | POST | No | Send forgot password OTP |
| 10 | /forgot-password/verify-otp | POST | No | Verify forgot password OTP |
| 11 | /forgot-password/set-password | POST | No | Set new password |

## Testing Checklist

- [ ] Server is running on http://192.168.1.16:3000
- [ ] MongoDB is running and accessible
- [ ] SMTP credentials are configured in .env.local
- [ ] Variables are properly set at the top of the HTTP file
- [ ] Token is updated after login

## Quick Test Commands

1. **Test if server is running:**
   - Check: http://192.168.1.16:3000/api/v1/health

2. **Test forgot password flow:**
   - Run requests 9 → 10 → 11 → 4 in sequence

3. **Test registration flow:**
   - Use a NEW email address
   - Run requests 1 → 2 → 3 → 4 in sequence

## Error Responses

All errors follow this format:
```json
{
  "success": false,
  "message": "Error description",
  "error": {
    "method": "POST",
    "path": "/api/drivers/..."
  }
}
```

## Success Responses

All successful responses follow this format:
```json
{
  "success": true,
  "message": "Success description",
  ...data
}
```
