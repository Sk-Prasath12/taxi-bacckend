# Driver App — Production Setup Guide (Step-by-Step)

Complete roadmap for building a production-ready **Driver App** with **Admin verification**, **Wallet**, **Ride management**, and **Customer App** integration.

**Projects in this ecosystem**

| Project | Path | Role |
|---------|------|------|
| Driver + test customer UI | `D:\Taxi deiver\taxi-app` | Flutter driver app |
| Customer app | `D:\taxiuser\taxi_customer_app` | Flutter customer app |
| API (Docker) | `http://localhost:3000` | `taxi_app_backend` container |
| Database | MongoDB `taxi_app_mongo` port `27018` | Persistent storage |

**Related docs**

- `TESTING.md` — dual-browser ride flow test
- `customer-flow.http` / `driver-flow.http` — REST examples
- `docker-patch/` — reference TypeScript for production API patterns
- `D:\taxiuser\taxi_customer_app\INTEGRATION_RIDE_FLOW.md` — customer ↔ driver handshake

---

## 1. System architecture

```
┌─────────────────┐     REST + Socket.IO      ┌──────────────────────┐
│  Customer App   │ ─────────────────────────►│                      │
│ taxi_customer   │   JWT role: CUSTOMER      │   taxi_app_backend   │
└─────────────────┘                           │   (port 3000)        │
                                              │                      │
┌─────────────────┐     REST + Socket.IO      │   MongoDB            │
│  Driver App     │ ─────────────────────────►│   (port 27018)       │
│  taxi-app       │   JWT role: DRIVER        │                      │
└─────────────────┘                           └──────────┬───────────┘
                                                         │
┌─────────────────┐     REST (admin JWT)                │
│  Admin Panel    │ ────────────────────────────────────┘
│  (future/web)   │
└─────────────────┘
```

**Golden rule:** Customer and driver apps never call each other directly. All coordination goes through the backend + Socket.IO.

---

## 2. Current status (what exists today)

### ✅ Working (use for E2E testing)

| Area | Status |
|------|--------|
| Driver login | `POST /api/drivers/login` → JWT stored in Hive |
| Persistent login | Token restored on app open → `DashboardPage` |
| Online / offline | `PATCH /api/drivers/status` + socket `driver:online` |
| Incoming rides | `GET /api/drivers/rides/incoming` + `new_ride` socket |
| Ride lifecycle | accept → arrived → verify-otp → picked-up → in-transit → dropped |
| Customer booking | request → confirm → tracking → invoice |
| Abandon stale ride | `POST /api/customers/rides/active/abandon` (Docker patch applied) |
| Forgot password OTP | Email OTP flow |

### ⚠️ Partial / buggy

| Area | Gap |
|------|-----|
| Registration OTP | Backend OK; Flutter often **does not save JWT** after `set-password` |
| Online status | App sends `ONLINE`/`OFFLINE`; backend expects `online`/`offline` |
| Wallet UI | Mock data; `getWallet` response path wrong (`data.balance`) |
| Withdraw UI | Never calls API; backend withdraw is a **stub** |
| JWT utils | Reads `sub` claim; backend uses `driverId` |

### ❌ Not implemented (required for production)

| Area | Gap |
|------|-----|
| Document upload | UI mock only; no S3/multer APIs |
| Admin verification | No `is_driver_verified` gate on accept |
| Refresh tokens | No `/refresh` endpoint |
| Profile update | `POST /api/v1/driver/profile` missing |
| Wallet ledger | No transactions collection |
| Bank / UPI payout | No payout integration |
| Driver notifications API | Customer notifications only |
| SMS OTP | Email only |

---

## 3. Implementation phases (step-by-step)

Work through phases in order. Do not enable **Go Online** for unverified drivers until **Phase 4** is complete.

---

### Phase 0 — Environment & infrastructure

**Goal:** Stable dev/prod stack everyone connects to.

#### Step 0.1 — Start services

```bash
# Backend + Mongo + OSRM (if using Docker Compose from backend image)
docker ps   # expect taxi_app_backend, taxi_app_mongo, taxi_osrm
curl http://localhost:3000/api/v1/health
```

#### Step 0.2 — Align API URLs

| App | Config file | Value |
|-----|-------------|-------|
| Driver | `lib/api/api_constants.dart` | `baseUrl: http://localhost:3000` |
| Customer | `.env.local` → `API_BASE_URL` | `http://localhost:3000` |
| Web testing | Both apps | Use `localhost:3000` |
| Physical device | Both apps | Use PC LAN IP, e.g. `http://192.168.1.4:3000` |

#### Step 0.3 — Seed data

```bash
# Chennai operational zone (required for ride request)
docker exec -i taxi_app_mongo mongosh -u taxiadmin -p taxi123 \
  --authenticationDatabase admin taxi_app < scripts/seed-chennai-zone.mongodb.js
```

#### Step 0.4 — Test accounts

Document in `TESTING.md`:

- Customer: `sk2011@yopmail.com` / `Sk@123456`
- Driver: `sridharshini@yopmail.com` / `sri@123456`

**Exit criteria:** Health 200, zone seeded, both apps reach login screen.

---

### Phase 1 — Authentication & persistent session

**Goal:** Register once, login once, stay logged in until logout.

#### Step 1.1 — Backend: unify JWT payload

```json
{
  "sub": "<userId>",
  "role": "DRIVER",
  "type": "access",
  "iat": ...,
  "exp": ...
}
```

- Access token: 15–60 minutes
- Refresh token: 7–30 days (store hashed in `refresh_tokens` collection)

**New endpoints**

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/drivers/register/email` | Send OTP |
| POST | `/api/drivers/register/verify-otp` | Verify OTP |
| POST | `/api/drivers/register/set-password` | Create account + return tokens |
| POST | `/api/drivers/login` | Login + tokens |
| POST | `/api/drivers/refresh` | Rotate access token |
| POST | `/api/drivers/logout` | Invalidate refresh token |

#### Step 1.2 — Database: `drivers` + `refresh_tokens`

```javascript
// drivers (or unified users with role=DRIVER)
{
  _id, name, email, phone, password_hash,
  role: "DRIVER",
  driver_verification_status: "PENDING" | "UNDER_REVIEW" | "APPROVED" | "REJECTED" | "SUSPENDED",
  is_driver_verified: false,
  is_blocked: false,
  date_of_birth, address,
  vehicle: { number, type_id, model, color },
  bank: { account_holder, account_number, ifsc, upi_id },
  status: "OFFLINE" | "ONLINE" | "BUSY",
  created_at, updated_at
}

// refresh_tokens
{
  user_id, token_hash, expires_at, device_id, revoked_at
}
```

#### Step 1.3 — Flutter driver app fixes

| File | Action |
|------|--------|
| `auth_service.dart` | After `set-password` and `login`, save **access + refresh** tokens to Hive |
| `auth_wrapper.dart` | On launch: if refresh valid → dashboard; else → login |
| `jwt_utils.dart` | Read `sub` OR `driverId` for user id |
| `api_client.dart` | On 401 → try refresh once → retry request |

#### Step 1.4 — Auth flow (driver)

```
Register → email OTP → verify → set password → save tokens → Profile wizard
Login    → save tokens → Dashboard (if APPROVED) or Verification pending screen
App open → refresh token → Dashboard
Logout   → revoke refresh + clear Hive → Login
```

**Exit criteria:** Kill app, reopen → lands on dashboard without re-login.

---

### Phase 2 — Driver profile & document upload

**Goal:** Collect all KYC before admin review.

#### Step 2.1 — Required personal fields

| Field | Required before go-online |
|-------|---------------------------|
| Full name | ✅ |
| Mobile | ✅ |
| Email | ✅ |
| Date of birth | ✅ |
| Address | ✅ |

**API:** `GET/PATCH /api/drivers/profile`

#### Step 2.2 — Required documents

| Document | Sides | Storage |
|----------|-------|---------|
| Driving license | Front + back | S3 / local `uploads/` |
| RC book | Front | S3 |
| Aadhaar | Front | S3 |
| PAN | Front | S3 |
| Profile photo | 1 | S3 |
| Vehicle photos | 2–4 | S3 |

**API**

| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/drivers/documents` | Multipart upload |
| GET | `/api/drivers/documents` | List + status per doc |
| DELETE | `/api/drivers/documents/:id` | Re-upload before approval |

**Document record**

```javascript
{
  driver_id, document_type, file_url, file_key,
  status: "PENDING" | "APPROVED" | "REJECTED",
  rejection_reason, uploaded_at, reviewed_at, reviewed_by
}
```

#### Step 2.3 — Flutter screens

| Screen | File | Wire to |
|--------|------|---------|
| Documents | `lib/documents/documents_page.dart` | `image_picker` + multipart POST |
| Vehicle details | `profile_page/vehicle_details_page.dart` | PATCH profile |
| Edit profile | `profile_page/edit_profile_page.dart` | PATCH profile |

**Validation:** Max 5 MB, JPEG/PNG/PDF only.

**Exit criteria:** New driver can upload all docs; URLs stored in MongoDB.

---

### Phase 3 — Admin verification panel

**Goal:** Admin approves/rejects drivers before they go online.

#### Step 3.1 — Admin APIs

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/admin/drivers/pending` | Pending applications |
| GET | `/api/admin/drivers/:id` | Full profile + documents |
| PATCH | `/api/admin/drivers/:id/documents/:docId` | Approve/reject document |
| POST | `/api/admin/drivers/:id/approve` | Final approval → create wallet |
| POST | `/api/admin/drivers/:id/reject` | Reject with reason |
| POST | `/api/admin/drivers/:id/suspend` | Suspend active driver |

#### Step 3.2 — On final approval

1. Set `is_driver_verified = true`, `driver_verification_status = APPROVED`
2. Create wallet document (Phase 5)
3. Push notification: "You are approved — you can go online"

#### Step 3.3 — Driver app restrictions

| Check | Where |
|-------|-------|
| Block online toggle if not `APPROVED` | `dashboard_page.dart` |
| Show status banner | `PENDING` / `UNDER_REVIEW` / `REJECTED` |
| Block `acceptRide` if not verified | Backend `acceptRide` → 403 |

**Exit criteria:** Unverified driver cannot go online or accept rides.

---

### Phase 4 — Online status & real-time ride dispatch

**Goal:** Approved drivers toggle online and receive rides.

#### Step 4.1 — Online flow

```
Driver taps ON DUTY
  → PATCH /api/drivers/status  { status: "online" }
  → Socket connect + emit driver:online { lat, lng }
  → Start GPS loop (every 3–12s)
  → Poll GET /api/drivers/rides/incoming (backup)
```

**Fix status casing:** Send lowercase `online` / `offline` / `busy` OR normalize on backend.

#### Step 4.2 — Socket events (driver)

| Event | Direction | Purpose |
|-------|-----------|---------|
| `join` | Client → Server | `{ userId, role: "driver" }` |
| `driver:online` | Client → Server | GPS + availability |
| `new_ride` | Server → Client | Incoming request (after customer **confirm**) |
| `ride_status_update` | Server → Client | Status changes |
| `driver_location` | Client → Server | Live GPS during ride |

#### Step 4.3 — Customer → driver handshake

```
Customer: POST /api/customers/rides/request
Customer: POST /api/customers/rides/confirm
Backend:  io.to("drivers").emit("new_ride", { ride_id, pickup, drop, fare })
Driver:   ring + popup → POST /api/drivers/rides/:id/accept
Backend:  emit ride_accepted + ride_status_update to customer room
```

**Files already wired**

- Driver: `driver_ride_listener_service.dart`, `dashboard_page.dart`, `ride_requests_page.dart`
- Customer: `ride_flow_service.dart`, `driver_searching_screen.dart`

**Exit criteria:** Customer confirm → driver hears alert → accept → customer sees driver on map.

---

### Phase 5 — Ride lifecycle (full trip)

**Goal:** Complete trip with OTP, navigation, and DB persistence.

#### Step 5.1 — Status machine

```
PENDING_CONFIRMATION → SEARCHING_DRIVER → DRIVER_ASSIGNED → ARRIVED_AT_PICKUP
  → OTP_VERIFIED / PICKED_UP → IN_TRANSIT → COMPLETED
```

| Driver action | API | Customer sees |
|---------------|-----|---------------|
| Accept | `POST .../accept` | Driver assigned |
| Arrived | `POST .../arrived` | Driver arrived |
| Verify OTP | `POST .../verify-otp` | Trip starting |
| Picked up | `POST .../picked-up` | On the way |
| In transit | `POST .../in-transit` | En route |
| Dropped | `POST .../dropped` | Completed → invoice |

#### Step 5.2 — Ride record (completed)

```javascript
{
  ride_id, customer_id, driver_id,
  pickup: { lat, lng, address },
  drop: { lat, lng, address },
  distance_km, duration_min, fare, currency,
  payment_mode, payment_status,
  driver_earnings, platform_commission,
  otp, otp_verified,
  status, timestamps: { requested, confirmed, accepted, arrived, started, completed }
}
```

#### Step 5.3 — Flutter active ride

`lib/drive_page/active_ride_page.dart` — OSRM route, markers, auto-return home after drop + cash received.

**Exit criteria:** Full trip stored in DB; customer invoice loads; driver returns to dashboard.

---

### Phase 6 — Wallet & earnings

**Goal:** Auto-credit driver wallet on ride completion.

#### Step 6.1 — Database collections

```javascript
// wallets — one per approved driver
{
  driver_id, balance, currency: "INR",
  total_earnings, total_withdrawn,
  created_at, updated_at
}

// wallet_transactions
{
  wallet_id, driver_id, type: "CREDIT" | "DEBIT",
  source: "RIDE" | "WITHDRAWAL" | "ADJUSTMENT",
  amount, balance_after,
  ride_id?, withdrawal_id?, description,
  created_at
}
```

#### Step 6.2 — On ride completion (`dropped`)

1. Calculate `driver_earnings = fare - commission`
2. Credit wallet atomically (MongoDB transaction)
3. Insert `wallet_transactions` row
4. Emit `wallet_credit` notification to driver

#### Step 6.3 — APIs

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/drivers/wallet` | Balance + summary |
| GET | `/api/drivers/wallet/transactions` | Paginated history |
| GET | `/api/drivers/earnings/total` | Lifetime earnings |
| GET | `/api/drivers/earnings/cash` | Cash rides summary |

#### Step 6.4 — Flutter fixes

| File | Fix |
|------|-----|
| `wallet_page.dart` | Parse `response.data.balance`; remove mock fallback |
| `withdraw_page.dart` | Load real balance + transactions |

**Exit criteria:** Complete ride → wallet balance increases → transaction visible in app.

---

### Phase 7 — Withdrawals (UPI & bank)

**Goal:** Driver withdraws earnings with admin approval.

#### Step 7.1 — Bank details on profile

```javascript
bank: {
  account_holder_name,
  account_number,    // encrypt at rest
  ifsc_code,
  upi_id
}
```

**API:** `PATCH /api/drivers/profile/bank`

#### Step 7.2 — Withdrawal flow

```
Driver requests withdrawal (amount, method: UPI | BANK)
  → POST /api/drivers/wallet/withdraw
  → Create withdrawal record (PENDING)
  → Debit wallet (hold) or validate balance
Admin approves
  → PATCH /api/admin/withdrawals/:id/approve
  → Process payout (Razorpay X / manual)
  → Status: COMPLETED | FAILED
  → Notify driver
```

```javascript
// withdrawals
{
  driver_id, amount, method: "UPI" | "BANK",
  status: "PENDING" | "APPROVED" | "PROCESSING" | "COMPLETED" | "REJECTED",
  bank_snapshot, upi_id, admin_note,
  requested_at, processed_at
}
```

**Exit criteria:** Withdrawal request → admin approval → balance updated → history shown.

---

### Phase 8 — Notifications

**Goal:** Push + in-app alerts for all key events.

| Event | Driver | Customer |
|-------|--------|----------|
| New ride | ✅ Sound + popup | — |
| Ride accepted | — | ✅ |
| Ride completed | ✅ Earnings | ✅ Invoice |
| Wallet credit | ✅ | — |
| Withdrawal status | ✅ | — |
| Admin approval | ✅ | — |
| Document rejected | ✅ | — |

**API**

| Method | Path |
|--------|------|
| POST | `/api/notifications/save-token` |
| GET | `/api/notifications/drivers` |
| GET | `/api/notifications/customers` |

**Flutter:** FCM on mobile; snackbar/dialog on web.

---

### Phase 9 — Security hardening

| Requirement | Implementation |
|-------------|----------------|
| JWT | Short access + refresh rotation |
| RBAC | `requireRole(['DRIVER'|'CUSTOMER'|'ADMIN'])` |
| Password | bcrypt cost ≥ 12 |
| Upload | MIME check, size limit, virus scan (optional) |
| Rate limit | `express-rate-limit` on auth routes |
| Encryption | Bank account fields encrypted in DB |
| HTTPS | Required in production |
| CORS | Whitelist app origins only |

---

### Phase 10 — Production deployment checklist

- [ ] MongoDB backups automated
- [ ] S3 bucket for documents (lifecycle + ACL)
- [ ] Environment secrets in vault (not `.env` in repo)
- [ ] Docker image rebuilt with all Phase 1–7 APIs
- [ ] `docker-patch/` merged into main backend source repo
- [ ] OSRM container on same network
- [ ] SSL termination (nginx / cloud load balancer)
- [ ] Monitoring: health, error rate, socket connections
- [ ] E2E test: `customer-flow.http` + `driver-flow.http` + `e2e-ride-flow.http`

---

## 4. Customer app connection map

Use this when changing driver APIs — customer app depends on these sync points:

| Step | Customer API / event | Driver API / event |
|------|---------------------|-------------------|
| 1 | `POST /customers/rides/request` | — |
| 2 | `POST /customers/rides/confirm` | `new_ride` socket |
| 3 | `join_ride_room` | `join` + ride room |
| 4 | `ride_accepted` socket | `POST /drivers/rides/:id/accept` |
| 5 | `driver_location` socket | `driver:online` / location emit |
| 6 | `ride_status_update` | arrived / verify-otp / picked-up / in-transit / dropped |
| 7 | `GET /customers/rides/:id/invoice` | dropped completes ride |
| 8 | `POST /customers/rides/active/abandon` | Clears stuck rides (no UI resume) |

**Customer app key files**

- `lib/services/ride_service.dart`
- `lib/services/socket_service.dart`
- `lib/services/ride_flow_service.dart`
- `lib/config/env_config.dart`

**Rule:** Same `API_BASE_URL` host on both apps. Customer never calls `/api/drivers/*`.

---

## 5. Driver app screen → API map

| Screen | Route / file | APIs |
|--------|--------------|------|
| Splash / auth | `auth_wrapper.dart` | refresh token |
| Login | `login_page.dart` | `POST /drivers/login` |
| Register | `register_page.dart` | register OTP flow |
| Dashboard | `dashboard_page.dart` | status, socket, incoming rides |
| Ride requests | `ride_requests_page.dart` | incoming, accept |
| Active ride | `active_ride_page.dart` | full lifecycle + route |
| Documents | `documents_page.dart` | `POST /drivers/documents` *(to build)* |
| Wallet | `wallet_page.dart` | `GET /drivers/wallet`, transactions |
| Withdraw | `withdraw_page.dart` | `POST /drivers/wallet/withdraw` |
| Profile | `profile_page.dart` | `GET/PATCH /drivers/profile` |

---

## 6. Suggested folder structure (backend)

```
backend/
├── models/
│   ├── Driver.js
│   ├── DriverDocument.js
│   ├── Wallet.js
│   ├── WalletTransaction.js
│   ├── Withdrawal.js
│   ├── RefreshToken.js
│   └── Ride.js
├── routes/
│   ├── driverRoutes.js
│   ├── driverDocumentRoutes.js
│   ├── driverWalletRoutes.js
│   ├── adminDriverRoutes.js
│   └── customerRoutes.js
├── controllers/
├── middleware/
│   ├── authMiddleware.js
│   ├── roleMiddleware.js
│   └── uploadMiddleware.js
├── services/
│   ├── walletService.js
│   ├── notificationService.js
│   └── storageService.js
└── sockets/
    └── index.js
```

---

## 7. Quick test sequence (after each phase)

### Auth (Phase 1)
```http
POST /api/drivers/login
GET  /api/drivers/profile   Authorization: Bearer ...
```

### Documents (Phase 2–3)
Upload docs → admin approve → `is_driver_verified: true`

### Ride E2E (Phase 4–5)
See `TESTING.md` — two browsers, customer confirm required.

### Wallet (Phase 6–7)
Complete ride → `GET /api/drivers/wallet` balance increased.

---

## 8. Priority order for your next sprint

| Priority | Task | Effort |
|----------|------|--------|
| P0 | Fix registration JWT save + persistent login | 1 day |
| P0 | Fix online status casing (`online`/`offline`) | 2 hours |
| P0 | Verification gate on accept ride | 4 hours |
| P1 | Document upload API + wire `documents_page.dart` | 3 days |
| P1 | Admin approve driver APIs | 2 days |
| P1 | Wallet ledger + credit on ride complete | 2 days |
| P2 | Refresh token flow | 1 day |
| P2 | Withdrawal with admin approval | 3 days |
| P2 | Driver notifications API + FCM | 2 days |
| P3 | SMS OTP, rate limiting, encryption | ongoing |

---

## 9. Expected final result

When all phases are complete:

1. Driver registers once with OTP verification.
2. Uploads all KYC documents.
3. Admin reviews and approves.
4. Driver goes online from dashboard.
5. Receives real-time ride requests (sound + popup).
6. Completes full ride flow with OTP and map.
7. Earnings auto-credit to wallet.
8. Driver withdraws via UPI or bank (admin-approved).
9. Login persists until manual logout.
10. Customer app books, tracks, and pays through the same backend.
11. All data permanently stored in MongoDB with audit trails.

---

*Last updated: production roadmap aligned with `taxi_app_backend` Docker (port 3000) and Flutter apps `taxi-app` + `taxi_customer_app`.*
