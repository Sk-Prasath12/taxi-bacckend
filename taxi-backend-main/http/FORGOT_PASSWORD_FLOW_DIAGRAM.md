# 🔄 Driver Forgot Password API - Flow Diagram

## Visual Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                     FORGOT PASSWORD FLOW                             │
└─────────────────────────────────────────────────────────────────────┘

Driver                        Backend                        Database
  │                              │                              │
  │  1. Request Password Reset   │                              │
  ├─────────────────────────────▶│                              │
  │  POST /forgot-password/email │                              │
  │  { email: "..." }            │                              │
  │                              │   Check Driver Exists        │
  │                              ├─────────────────────────────▶│
  │                              │   findOne({email, role})     │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Delete Old OTPs            │
  │                              ├─────────────────────────────▶│
  │                              │   deleteMany({verified:false})│
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Generate New OTP           │
  │                              │   - 6-digit random           │
  │                              │   - 5 min expiry             │
  │                              │                              │
  │                              │   Save OTP                   │
  │                              ├─────────────────────────────▶│
  │                              │   create({email, otp, ...})  │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Send Email (optional)      │
  │                              │   ┌──────────────────────┐   │
  │                              │   │ Try to send email    │   │
  │                              │   │ If fails, continue   │   │
  │                              │   │ OTP still works!     │   │
  │                              │   └──────────────────────┘   │
  │                              │                              │
  │  Success Response            │                              │
  │◀─────────────────────────────┤                              │
  │  { success: true, ... }      │                              │
  │                              │                              │
  │  2. Verify OTP               │                              │
  ├─────────────────────────────▶│                              │
  │  POST /forgot-password/      │                              │
  │       verify-otp             │                              │
  │  { email, otp }              │   Find OTP Record            │
  │                              ├─────────────────────────────▶│
  │                              │   findOne({email, purpose})  │
  │                              │   .sort({createdAt:-1})      │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Validate:                  │
  │                              │   ✓ OTP exists               │
  │                              │   ✓ Not expired              │
  │                              │   ✓ OTP matches (or 123456)  │
  │                              │                              │
  │                              │   Mark as Verified           │
  │                              ├─────────────────────────────▶│
  │                              │   otpRecord.verified = true  │
  │                              │   otpRecord.save()           │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │  Success Response            │                              │
  │◀─────────────────────────────┤                              │
  │  { success: true, ... }      │                              │
  │                              │                              │
  │  3. Set New Password         │                              │
  ├─────────────────────────────▶│                              │
  │  POST /forgot-password/      │                              │
  │       set-password           │                              │
  │  { email, password }         │   Check Driver Exists        │
  │                              ├─────────────────────────────▶│
  │                              │   findOne({email, role})     │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Find Verified OTP          │
  │                              ├─────────────────────────────▶│
  │                              │   findOne({verified:true})   │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Validate:                  │
  │                              │   ✓ OTP verified             │
  │                              │   ✓ Not expired              │
  │                              │                              │
  │                              │   Hash Password (bcrypt)     │
  │                              │                              │
  │                              │   Update Driver              │
  │                              ├─────────────────────────────▶│
  │                              │   driver.password_hash = ... │
  │                              │   driver.save()              │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Delete All OTPs            │
  │                              ├─────────────────────────────▶│
  │                              │   deleteMany({email,...})    │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │  Success Response            │                              │
  │◀─────────────────────────────┤                              │
  │  { success: true, ... }      │                              │
  │                              │                              │
  │  4. Login with New Password  │                              │
  ├─────────────────────────────▶│                              │
  │  POST /login                 │   Find Driver                │
  │  { email, password }         ├─────────────────────────────▶│
  │                              │   findOne({email, role})     │
  │                              │◀─────────────────────────────┤
  │                              │                              │
  │                              │   Verify Password            │
  │                              │   comparePassword()          │
  │                              │                              │
  │                              │   Generate JWT Token         │
  │                              │   generateAccessToken()      │
  │                              │                              │
  │  Token + User Info           │                              │
  │◀─────────────────────────────┤                              │
  │  { token, user }             │                              │
  │                              │                              │
  ▼                              ▼                              ▼
```

---

## Sequence Diagram

```
┌────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
│ Driver │         │  Server  │         │  MongoDB │         │   SMTP   │
└───┬────┘         └────┬─────┘         └────┬─────┘         └────┬─────┘
    │                   │                    │                    │
    │  1. POST /forgot- │                    │                    │
    │     password/email│                    │                    │
    ├──────────────────▶│                    │                    │
    │                   │  Check driver      │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Driver found      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Delete old OTPs   │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Old OTPs deleted  │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Create new OTP    │                    │
    │                   ├───────────────────▶│                    │
    │                   │  OTP saved         │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Send email        │                    │
    │                   │────────────────────────────────────────▶│
    │                   │  Email sent (or    │                    │
    │                   │  failed but OK)    │                    │
    │                   │◀────────────────────────────────────────┤
    │                   │                    │                    │
    │  OTP sent success │                    │                    │
    │◀──────────────────┤                    │                    │
    │                   │                    │                    │
    │  2. POST /forgot- │                    │                    │
    │     password/     │                    │                    │
    │     verify-otp    │                    │                    │
    ├──────────────────▶│                    │                    │
    │                   │  Find OTP record   │                    │
    │                   ├───────────────────▶│                    │
    │                   │  OTP record        │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Validate OTP      │                    │
    │                   │  (exists, expiry,  │                    │
    │                   │   matches/123456)  │                    │
    │                   │                    │                    │
    │                   │  Mark verified     │                    │
    │                   ├───────────────────▶│                    │
    │                   │  OTP verified      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │  OTP verified     │                    │                    │
    │  success          │                    │                    │
    │◀──────────────────┤                    │                    │
    │                   │                    │                    │
    │  3. POST /forgot- │                    │                    │
    │     password/     │                    │                    │
    │     set-password  │                    │                    │
    ├──────────────────▶│                    │                    │
    │                   │  Find driver       │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Driver found      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Find verified OTP │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Verified OTP      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Validate OTP      │                    │
    │                   │  (verified, not    │                    │
    │                   │   expired)         │                    │
    │                   │                    │                    │
    │                   │  Hash password     │                    │
    │                   │  (bcrypt)          │                    │
    │                   │                    │                    │
    │                   │  Update password   │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Password updated  │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Delete all OTPs   │                    │
    │                   ├───────────────────▶│                    │
    │                   │  OTPs deleted      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │  Password reset   │                    │                    │
    │  success          │                    │                    │
    │◀──────────────────┤                    │                    │
    │                   │                    │                    │
    │  4. POST /login   │                    │                    │
    ├──────────────────▶│                    │                    │
    │                   │  Find driver       │                    │
    │                   ├───────────────────▶│                    │
    │                   │  Driver found      │                    │
    │                   │◀───────────────────┤                    │
    │                   │                    │                    │
    │                   │  Verify password   │                    │
    │                   │  (bcrypt compare)  │                    │
    │                   │                    │                    │
    │                   │  Generate JWT      │                    │
    │                   │  token             │                    │
    │                   │                    │                    │
    │  Token + User     │                    │                    │
    │◀──────────────────┤                    │                    │
    │                   │                    │                    │
    ▼                   ▼                    ▼                    ▼
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     DATA FLOW DIAGRAM                        │
└─────────────────────────────────────────────────────────────┘

Step 1: Send OTP
─────────────────
Input:  { email: "skprasath@yopmail.com" }
         ↓
Normalize: email.toLowerCase().trim()
         ↓
Query: UserModel.findOne({ email, role: "DRIVER" })
         ↓
If not found → 404 Error
         ↓
Delete old OTPs: DriverOtpModel.deleteMany({ email, purpose, verified: false })
         ↓
Generate OTP: Math.floor(100000 + Math.random() * 900000) → "456789"
         ↓
Set expiry: new Date(Date.now() + 5 * 60 * 1000)
         ↓
Save OTP: DriverOtpModel.create({ purpose, email, otp, expiresAt, verified })
         ↓
Send email: transporter.sendMail({ from, to, subject, html })
         ↓
Output: { success: true, message: "OTP sent successfully" }


Step 2: Verify OTP
─────────────────
Input:  { email: "skprasath@yopmail.com", otp: "123456" }
         ↓
Normalize: email.toLowerCase().trim()
         ↓
Find OTP: DriverOtpModel.findOne({ email, purpose }).sort({ createdAt: -1 })
         ↓
If not found → 400 Error: "OTP not found"
         ↓
Check expiry: otpRecord.expiresAt.getTime() < Date.now()
         ↓
If expired → 400 Error: "OTP has expired"
         ↓
Validate OTP: otpRecord.otp !== otp && otp !== "123456"
         ↓
If invalid → 400 Error: "Invalid OTP"
         ↓
Mark verified: otpRecord.verified = true; otpRecord.save()
         ↓
Output: { success: true, message: "OTP verified successfully" }


Step 3: Set Password
─────────────────
Input:  { email: "skprasath@yopmail.com", password: "newPass123" }
         ↓
Normalize: email.toLowerCase().trim()
         ↓
Find driver: UserModel.findOne({ email, role: "DRIVER" })
         ↓
If not found → 404 Error: "Driver not found"
         ↓
Find verified OTP: DriverOtpModel.findOne({ email, purpose, verified: true })
         ↓
If not found → 400 Error: "Email is not verified"
         ↓
Check OTP expiry: otpRecord.expiresAt.getTime() < Date.now()
         ↓
If expired → 400 Error: "Verified OTP has expired"
         ↓
Hash password: await hashPassword(password) → "$2b$10$..."
         ↓
Update driver: driver.password_hash = hashedPassword; driver.save()
         ↓
Cleanup OTPs: DriverOtpModel.deleteMany({ email, purpose })
         ↓
Output: { success: true, message: "Password reset successfully" }


Step 4: Login
─────────────────
Input:  { email: "skprasath@yopmail.com", password: "newPass123" }
         ↓
Normalize: email.toLowerCase().trim()
         ↓
Find driver: UserModel.findOne({ email, role: "DRIVER" })
         ↓
If not found → 401 Error: "Invalid email or password"
         ↓
Check active: driver.is_active
         ↓
If inactive → 403 Error: "Driver account is inactive"
         ↓
Verify password: await comparePassword(password, driver.password_hash)
         ↓
If invalid → 401 Error: "Invalid email or password"
         ↓
Generate token: generateAccessToken(driver.id, "DRIVER")
         ↓
Output: { token: "eyJhbGci...", user: { id, name, email, role, status, ... } }
```

---

## State Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      OTP STATE DIAGRAM                       │
└─────────────────────────────────────────────────────────────┘

                    ┌──────────────┐
                    │   No OTP     │
                    │   (Initial)  │
                    └──────┬───────┘
                           │
                           │ Request Password Reset
                           │ (POST /forgot-password/email)
                           ↓
                    ┌──────────────┐
                    │   OTP Created│
                    │   (Unverified)│
                    │              │
                    │  expires in  │
                    │  5 minutes   │
                    └──┬────────┬──┘
                       │        │
          OTP Verified │        │ OTP Expired
          (correct     │        │ (5 min passed)
          code/123456) │        │
                       ↓        ↓
                ┌──────────┐  ┌──────────┐
                │ Verified │  │ Expired  │
                │   OTP    │  │   OTP    │
                └────┬─────┘  └────┬─────┘
                     │             │
                     │ Set         │ Request
                     │ Password    │ New OTP
                     ↓             ↓
                ┌──────────┐  ┌──────────┐
                │ Password │  │   OTP    │
                │  Reset   │  │  Created │
                │ Success  │  │(Unverified)
                └──────────┘  └──────────┘
                     │
                     │ OTPs Deleted
                     │ (cleanup)
                     ↓
                ┌──────────┐
                │   No OTP │
                │ (Clean)  │
                └──────────┘
```

---

## Error Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      ERROR FLOW DIAGRAM                      │
└─────────────────────────────────────────────────────────────┘

Request: POST /forgot-password/email
         ↓
    ┌────────────────┐
    │ Email valid?   │──No──→ 400: Bad Request
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ Driver exists? │──No──→ 404: Driver not found
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ OTP created?   │──No──→ 500: Internal server error
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ Email sent?    │──No──→ Continue (OTP still works)
    └────────┬───────┘
             │ Yes/No
             ↓
        200: Success


Request: POST /forgot-password/verify-otp
         ↓
    ┌────────────────┐
    │ OTP exists?    │──No──→ 400: OTP not found
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ OTP expired?   │──Yes──→ 400: OTP has expired
    └────────┬───────┘
             │ No
             ↓
    ┌────────────────┐
    │ OTP matches?   │──No──→ 400: Invalid OTP
    │ (or 123456)    │
    └────────┬───────┘
             │ Yes
             ↓
        200: Success


Request: POST /forgot-password/set-password
         ↓
    ┌────────────────┐
    │ Driver exists? │──No──→ 404: Driver not found
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ OTP verified?  │──No──→ 400: Email is not verified
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ OTP expired?   │──Yes──→ 400: Verified OTP has expired
    └────────┬───────┘
             │ No
             ↓
    ┌────────────────┐
    │ Password valid?│──No──→ 400: Validation error
    │ (min 8 chars)  │
    └────────┬───────┘
             │ Yes
             ↓
    ┌────────────────┐
    │ Password       │──No──→ 500: Internal server error
    │ hashed & saved?│
    └────────┬───────┘
             │ Yes
             ↓
        200: Success
```

---

## Database Operations

```
┌─────────────────────────────────────────────────────────────┐
│                   DATABASE OPERATIONS                        │
└─────────────────────────────────────────────────────────────┘

Collection: users
─────────────────
Query 1: findOne({ email: normalizedEmail, role: "DRIVER" })
Purpose: Check if driver exists
Used in: Send OTP, Set Password, Login

Query 2: findById(userId)
Purpose: Get driver by ID
Used in: Get Profile, Update Status

Update: driver.password_hash = hashedPassword; driver.save()
Purpose: Update password
Used in: Set Password


Collection: driver_email_otps
──────────────────────────────
Query 1: deleteMany({ email, purpose, verified: false })
Purpose: Clean up old unverified OTPs
Used in: Send OTP

Query 2: create({ purpose, email, otp, expiresAt, verified })
Purpose: Store new OTP
Used in: Send OTP

Query 3: findOne({ email, purpose }).sort({ createdAt: -1 })
Purpose: Get latest OTP
Used in: Verify OTP

Query 4: otpRecord.verified = true; otpRecord.save()
Purpose: Mark OTP as verified
Used in: Verify OTP

Query 5: findOne({ email, purpose, verified: true }).sort({ createdAt: -1 })
Purpose: Get verified OTP
Used in: Set Password

Query 6: deleteMany({ email, purpose })
Purpose: Clean up all OTPs after password reset
Used in: Set Password

Indexes:
- email + purpose (compound)
- expiresAt (TTL - auto-deletes expired records)
```

---

## Security Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     SECURITY FLOW                            │
└─────────────────────────────────────────────────────────────┘

Input Validation
────────────────
1. Email format validation (Zod)
   ✓ Valid email format
   ✓ Lowercase conversion
   ✓ Trim whitespace

2. OTP format validation (Zod)
   ✓ Exactly 6 digits
   ✓ Regex: /^[0-9]{6}$/

3. Password validation (Zod)
   ✓ Minimum 8 characters
   ✓ No maximum limit


Password Security
─────────────────
1. Hashing Algorithm: bcrypt
2. Salt Rounds: 10
3. Process:
   Input: "driver12334"
      ↓
   hashPassword(password)
      ↓
   Output: "$2b$10$abc123def456..."
      ↓
   Stored in: driver.password_hash

4. Verification:
   Input: "driver12334" + "$2b$10$abc123..."
      ↓
   comparePassword(password, hash)
      ↓
   Output: true/false


OTP Security
────────────
1. Generation:
   Math.floor(100000 + Math.random() * 900000)
   → 6-digit random number

2. Expiry:
   5 minutes from creation
   → expiresAt: new Date(Date.now() + 5 * 60 * 1000)

3. Auto-cleanup:
   MongoDB TTL index on expiresAt
   → Automatically deletes expired records

4. One-time use:
   - OTP marked as verified after use
   - All OTPs deleted after password reset

5. Rate limiting:
   - Old unverified OTPs deleted before creating new one
   - Prevents OTP accumulation


JWT Token Security
──────────────────
1. Generation:
   jwt.sign(payload, secret, options)
   - Payload: { sub: userId, role: "DRIVER", type: "access" }
   - Secret: env.JWT_ACCESS_SECRET
   - Expiry: 15 minutes

2. Verification:
   jwt.verify(token, secret)
   - Checks signature
   - Checks expiry
   - Returns payload

3. Protected Routes:
   - requireAuth middleware
   - requireRole(["DRIVER"]) middleware
```

---

## Complete Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        COMPLETE ARCHITECTURE                          │
└─────────────────────────────────────────────────────────────────────┘

Client (HTTP File / App / cURL)
         │
         │ HTTP Requests
         ↓
┌──────────────────────────────┐
│        Express Server         │
│  (src/app.ts)                 │
│                               │
│  Routes:                      │
│  /api/drivers/                │
│    forgot-password/email      │
│    forgot-password/verify-otp │
│    forgot-password/set-password│
│    login                      │
└──────────┬───────────────────┘
           │
           │ Middleware Chain
           ↓
┌──────────────────────────────┐
│      Validation Layer         │
│  (Zod Schemas)                │
│                               │
│  ✓ Email format               │
│  ✓ OTP format                 │
│  ✓ Password length            │
└──────────┬───────────────────┘
           │
           ↓
┌──────────────────────────────┐
│     Controller Layer          │
│  (driver.controller.ts)       │
│                               │
│  ✓ Extract request body       │
│  ✓ Call service functions     │
│  ✓ Return responses           │
│  ✓ Error handling             │
└──────────┬───────────────────┘
           │
           ↓
┌──────────────────────────────┐
│      Service Layer            │
│  (driver.service.ts)          │
│                               │
│  ✓ Business logic             │
│  ✓ OTP generation             │
│  ✓ Email sending              │
│  ✓ Password hashing           │
│  ✓ Token generation           │
└──────────┬───────────────────┘
           │
           ├──────────────┬──────────────┐
           ↓              ↓              ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   MongoDB    │  │   Nodemailer │  │   JWT Utils  │
│              │  │              │  │              │
│ • Users      │  │ • SMTP       │  │ • Generate   │
│ • OTPs       │  │ • Email      │  │ • Verify     │
│              │  │ • Templates  │  │ • Secrets    │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

**End of Flow Diagrams**
