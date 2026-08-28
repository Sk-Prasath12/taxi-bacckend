# Taxi User – Backend Structure (Detailed)

Complete structure for building the backend that serves the taxi_user Flutter app. Covers auth, booking, orders, order history, count, earnings, stats, routes, reviews, and WebSocket.

---

## 1. Tech Stack (Suggested)

| Layer        | Choice              | Notes                                      |
|-------------|---------------------|--------------------------------------------|
| Runtime     | Node.js 18+         | LTS                                        |
| Framework   | NestJS or Express   | NestJS for modules/DI, Express for minimal |
| API         | REST + Socket.IO    | Base path: `/api/v1`, WebSocket on same host |
| Database    | PostgreSQL 14+      | Or MySQL; use migrations                   |
| ORM         | Prisma or TypeORM   | Prisma recommended for schema + migrations |
| Cache       | Redis (optional)   | For OTP, rate limit, session               |
| Email       | Nodemailer + SMTP   | Or SendGrid/Mailgun for OTP                |
| Auth        | JWT (access + refresh) | Access 15m–1h, refresh 7d             |
| Validation  | class-validator + class-transformer | DTOs |

---

## 2. Project Folder Structure

```
taxi_app_backend/
├── src/
│   ├── main.ts                    # Bootstrap app, CORS, global prefix /api/v1
│   ├── app.module.ts              # Imports all modules
│   │
│   ├── common/                    # Shared across modules
│   │   ├── decorators/            # @CurrentUser(), @Public()
│   │   ├── filters/               # HttpExceptionFilter
│   │   ├── guards/                # JwtAuthGuard
│   │   ├── interceptors/          # Transform response { data, message }
│   │   ├── pipes/                  # ValidationPipe
│   │   └── interfaces/             # JwtPayload, ApiResponse
│   │
│   ├── config/
│   │   ├── config.module.ts
│   │   ├── database.config.ts     # DB_URL, etc.
│   │   ├── jwt.config.ts
│   │   └── redis.config.ts        # Optional
│   │
│   ├── auth/
│   │   ├── auth.module.ts
│   │   ├── auth.controller.ts     # All auth routes under /auth
│   │   ├── auth.service.ts        # Register, OTP, login, refresh, profile
│   │   ├── strategies/            # JwtStrategy, JwtRefreshStrategy
│   │   ├── dto/                   # RegisterDto, LoginDto, etc.
│   │   └── entities/              # If auth has its own (e.g. RefreshToken)
│   │
│   ├── users/
│   │   ├── users.module.ts
│   │   ├── users.service.ts       # CRUD user, profile update
│   │   ├── users.controller.ts    # Maybe only internal or /users/me
│   │   └── entities/
│   │       └── user.entity.ts
│   │
│   ├── booking/
│   │   ├── booking.module.ts
│   │   ├── booking.controller.ts  # All routes under /booking
│   │   ├── booking.service.ts     # Orchestrates types, locations, orders, stats
│   │   ├── dto/
│   │   │   ├── create-location.dto.ts
│   │   │   ├── create-order.dto.ts
│   │   │   ├── confirm-order.dto.ts
│   │   │   ├── cancel-order.dto.ts
│   │   │   └── create-review.dto.ts
│   │   ├── entities/              # Or in separate modules
│   │   └── services/              # Optional: OrderService, LocationService
│   │
│   ├── orders/                    # Optional: split from booking
│   │   ├── orders.module.ts
│   │   ├── orders.service.ts      # CRUD orders, status, history, stats
│   │   ├── orders.controller.ts  # Or under booking controller
│   │   └── entities/
│   │       └── order.entity.ts
│   │
│   ├── locations/
│   │   ├── locations.service.ts   # User saved locations
│   │   └── entities/
│   │       └── user_location.entity.ts
│   │
│   ├── reviews/
│   │   ├── reviews.service.ts
│   │   └── entities/
│   │       └── review.entity.ts
│   │
│   ├── master/                     # Master data (vehicle types, package types, booking types)
│   │   ├── master.module.ts
│   │   ├── master.service.ts
│   │   └── entities/
│   │       ├── vehicle_type.entity.ts
│   │       ├── package_type.entity.ts
│   │       └── booking_type.entity.ts
│   │
│   ├── stats/                      # Aggregations: ride count, earnings, distance
│   │   ├── stats.service.ts
│   │   └── stats.controller.ts    # Or under booking
│   │
│   ├── gateway/                    # WebSocket (Socket.IO)
│   │   ├── gateway.module.ts
│   │   ├── gateway.gateway.ts      # Socket server, auth via handshake token
│   │   └── gateway.service.ts     # Emit to user/driver rooms
│   │
│   └── health/
│       └── health.controller.ts   # GET /health
│
├── prisma/                         # If using Prisma
│   ├── schema.prisma
│   └── migrations/
│
├── scripts/                        # OTP mail, seed, allow-firewall
├── test/
├── .env.example
├── package.json
└── tsconfig.json
```

---

## 3. Database Schema (Every Table & Column)

### 3.1 Users & Auth

**user**
| Column        | Type         | Constraints        | Description                |
|---------------|--------------|--------------------|----------------------------|
| id            | PK, serial   |                    |                            |
| email         | varchar(255) | UNIQUE, NOT NULL   | Lowercase                  |
| password_hash | varchar(255) | NULL until set     | Bcrypt                     |
| name          | varchar(255) | NOT NULL           |                            |
| phone         | varchar(50)  |                    |                            |
| gender        | varchar(20)  |                    | male, female, other        |
| role          | varchar(30)  | DEFAULT 'customer' | customer, driver, porter   |
| street        | varchar(255) |                    | Profile address            |
| city          | varchar(100) |                    |                            |
| pin_code      | varchar(20)  |                    |                            |
| email_verified| boolean      | DEFAULT false      |                            |
| created_at    | timestamptz  | DEFAULT now()      |                            |
| updated_at    | timestamptz  | DEFAULT now()      |                            |

**refresh_token** (optional, for JWT refresh)
| Column     | Type        | Description        |
|------------|-------------|--------------------|
| id         | PK          |                    |
| user_id    | FK → user   |                    |
| token      | varchar(512)| Hashed or random   |
| expires_at | timestamptz |                    |
| created_at | timestamptz |                    |

**otp**
| Column     | Type         | Description              |
|------------|--------------|--------------------------|
| id         | PK           |                          |
| email      | varchar(255) | NOT NULL, indexed        |
| otp_code   | varchar(10)  | 6-digit                  |
| purpose    | varchar(30)  | signup, login, reset     |
| expires_at | timestamptz  | e.g. now() + 10 min     |
| used       | boolean      | DEFAULT false            |
| created_at | timestamptz  |                          |

---

### 3.2 Master Data

**vehicle_type**
| Column   | Type         | Description        |
|----------|--------------|--------------------|
| id       | PK           |                    |
| name     | varchar(100) | Mini, Sedan, SUV   |
| slug     | varchar(50)  | mini, sedan        |
| base_fare| decimal(10,2)|                    |
| per_km   | decimal(10,2)|                    |
| per_min  | decimal(10,2)|                    |
| is_active| boolean      | DEFAULT true       |
| sort_order| int          |                    |

**package_type**
| Column   | Type         | Description     |
|----------|--------------|-----------------|
| id       | PK           |                 |
| name     | varchar(100) |                 |
| slug     | varchar(50)  |                 |
| max_kg   | decimal(8,2) | Max weight      |
| is_active| boolean     | DEFAULT true    |

**booking_type**
| Column    | Type         | Description        |
|-----------|--------------|--------------------|
| id        | PK           |                    |
| name      | varchar(100) | Ride, Parcel, etc. |
| slug      | varchar(50)  |                    |
| is_active | boolean      | DEFAULT true       |

---

### 3.3 User Locations (Saved Addresses)

**user_location**
| Column   | Type         | Constraints | Description     |
|----------|--------------|-------------|-----------------|
| id       | PK           |             |                 |
| user_id  | FK → user    | NOT NULL    |                 |
| label    | varchar(100) |             | Home, Work      |
| address  | text         |             | Full address    |
| street   | varchar(255) |             |                 |
| city     | varchar(100) |             |                 |
| lat      | decimal(11,8)| NOT NULL    |                 |
| lng      | decimal(11,8)| NOT NULL    |                 |
| created_at | timestamptz |             |                 |
| updated_at | timestamptz |             |                 |

Index: `(user_id)`.

---

### 3.4 Orders (Rides) – Core

**order**
| Column           | Type          | Constraints | Description                    |
|------------------|---------------|-------------|--------------------------------|
| id               | PK            |             |                                |
| user_id          | FK → user     | NOT NULL    | Customer                       |
| driver_id        | FK → user     | NULL        | Set when assigned              |
| status           | varchar(30)   | NOT NULL    | See Order Statuses below       |
| pickup_location_id | FK → user_location | NULL  | Saved location or NULL         |
| pickup_address   | text          |             | Resolved address               |
| pickup_lat       | decimal(11,8) |             |                                |
| pickup_lng       | decimal(11,8) |             |                                |
| drop_address     | text          | NOT NULL    |                                |
| drop_lat         | decimal(11,8) | NOT NULL    |                                |
| drop_lng         | decimal(11,8) | NOT NULL    |                                |
| receiver_name    | varchar(255)  |             | For parcel                     |
| receiver_phone   | varchar(50)   |             |                                |
| booking_type_id  | FK            |             |                                |
| vehicle_type_id  | FK            | NOT NULL    |                                |
| package_type_id  | FK            | NULL        | For parcel                     |
| weight_kg        | decimal(6,2)   | NULL        |                                |
| payer_type       | varchar(20)   |             | SENDER, RECEIVER               |
| payment_mode     | varchar(20)   |             | CASH, CARD, UPI, WALLET        |
| estimated_distance_km | decimal(8,2) | NULL  | From OSRM or estimate          |
| estimated_duration_min | int        | NULL        |                                |
| estimated_fare   | decimal(10,2) | NULL        | Pre-calculated                 |
| final_distance_km| decimal(8,2) | NULL        | After trip                     |
| final_duration_min | int        | NULL        |                                |
| subtotal         | decimal(10,2) | NULL        |                                |
| tax              | decimal(10,2) | NULL        |                                |
| total_amount     | decimal(10,2) | NULL        | Amount user paid               |
| cancel_reason    | text          | NULL        | If cancelled                   |
| cancelled_at     | timestamptz   | NULL        |                                |
| cancelled_by     | varchar(20)   | NULL        | user, driver, system           |
| confirmed_at     | timestamptz   | NULL        | When user confirmed            |
| assigned_at      | timestamptz   | NULL        | When driver assigned           |
| started_at       | timestamptz   | NULL        | Trip start                     |
| completed_at     | timestamptz   | NULL        | Trip end                       |
| route_polyline   | text          | NULL        | Encoded polyline or JSON array |
| created_at       | timestamptz   | DEFAULT now()|                               |
| updated_at       | timestamptz   | DEFAULT now()|                               |

Indexes: `(user_id)`, `(driver_id)`, `(status)`, `(user_id, status)`, `(created_at DESC)`.

**Order statuses (enum or check):**
- `DRAFT` – Created, not confirmed
- `PENDING` – Confirmed, finding driver
- `ASSIGNED` – Driver assigned
- `DRIVER_ARRIVED` – Driver at pickup
- `IN_PROGRESS` – Trip started
- `COMPLETED` – Trip ended, paid
- `CANCELLED` – Cancelled by user/driver/system

---

### 3.5 Reviews

**review**
| Column    | Type         | Constraints | Description |
|-----------|--------------|-------------|-------------|
| id        | PK           |             |             |
| order_id  | FK → order   | UNIQUE      | One per order |
| user_id   | FK → user    | NOT NULL    | Customer    |
| driver_id | FK → user    | NOT NULL    |             |
| rating    | smallint     | 1–5         |             |
| title     | varchar(255) |             |             |
| comment   | text         |             |             |
| created_at| timestamptz  |             |             |

---

### 3.6 Route Storage (Optional)

If you store route per order (for “ride history with route”):

- Either store **route_polyline** (encoded string or JSON array of `[lat,lng]`) on `order` (see above).
- Or separate table **order_route**:
  - order_id (FK), sequence (int), lat, lng.

Use one approach so GET order by id and list orders can return route when `includeRoute=true`.

---

## 4. API Endpoints (Detailed)

Base URL: `http://<host>:3000/api/v1`

Standard success response: `{ "data": T, "message"?: string }`.  
Error: `{ "message": string, "statusCode": number }`.

---

### 4.1 Health

| Method | Path     | Auth | Description        |
|--------|----------|------|--------------------|
| GET    | /health  | No   | 200 OK, backend up |

---

### 4.2 Auth (`/auth`)

| Method | Path                    | Auth | Description                    |
|--------|-------------------------|------|--------------------------------|
| POST   | /auth/register          | No   | Register + send OTP to email   |
| POST   | /auth/register/send-otp  | No   | Resend signup OTP              |
| POST   | /auth/register/verify-otp | No | Verify OTP (signup)            |
| POST   | /auth/otp-verification  | No   | Alias or same as verify-otp    |
| POST   | /auth/setup-password   | No   | Set password after signup OTP  |
| POST   | /auth/login            | No   | Email + password → access + refresh |
| POST   | /auth/login/send-otp   | No   | Send login OTP                 |
| POST   | /auth/login/verify-otp | No   | Login with OTP → tokens        |
| POST   | /auth/refresh          | No   | Body: { refreshToken } → new tokens |
| POST   | /auth/forget-password  | No   | Send OTP for reset             |
| POST   | /auth/reset-password   | No   | Email + OTP + new password     |
| GET    | /auth/profile          | Yes  | Current user profile           |
| PUT    | /auth/profile          | Yes  | Update profile (name, phone, address) |

**Request bodies (examples):**

- Register: `{ name, email, phone, gender, role? }`
- Verify OTP: `{ email, otp }`
- Setup password: `{ email, otp, password }`
- Login: `{ email, password }`
- Login verify: `{ email, otp }`
- Refresh: `{ refreshToken }`
- Reset password: `{ email, otp, password }`
- Update profile: `{ name?, phone?, street?, city?, pin_code? }`

---

### 4.3 Booking – Master Data (`/booking`)

All require auth unless noted.

| Method | Path                         | Auth | Description              |
|--------|------------------------------|------|--------------------------|
| GET    | /booking/types               | Yes  | List booking types       |
| GET    | /booking/vehicle-types       | Yes  | List vehicle types       |
| GET    | /booking/package-types       | Yes  | List package types       |

Response: `{ "data": [ { id, name, slug, ... } ] }`.

---

### 4.4 Booking – Locations (`/booking/locations`)

| Method | Path                    | Auth | Description        |
|--------|-------------------------|------|--------------------|
| GET    | /booking/locations      | Yes  | List user’s saved locations |
| POST   | /booking/locations      | Yes  | Create saved location       |

POST body: `{ label, address, street?, city?, lat, lng }`.  
Response: `{ "data": { id, userId, label, address, street, city, lat, lng, createdAt } }`.

---

### 4.5 Booking – Orders (`/booking/orders`)

| Method | Path                           | Auth | Description                    |
|--------|--------------------------------|------|--------------------------------|
| POST   | /booking/orders                | Yes  | Create draft order             |
| PUT    | /booking/orders/:id/confirm    | Yes  | Confirm → PENDING, notify drivers |
| GET    | /booking/orders/:id            | Yes  | Order details (optional route) |
| GET    | /booking/orders                | Yes  | Order history (paginated, filter) |
| PUT    | /booking/orders/:id/cancel     | Yes  | Cancel order (reason optional) |
| POST   | /booking/orders/:id/review     | Yes  | Post review (after COMPLETED)  |

**Create order body (DTO):**
- `pickupLocationId` (int, optional) – from saved locations
- `pickupAddress`, `pickupLat`, `pickupLng` (optional if pickupLocationId set)
- `dropAddress`, `dropLat`, `dropLng` (required)
- `receiverName`, `receiverPhone` (optional, for parcel)
- `bookingTypeId`, `vehicleTypeId`, `packageTypeId` (optional for parcel)
- `weightKg` (optional)
- `payerType`: SENDER | RECEIVER
- `paymentMode`: CASH | CARD | UPI | WALLET

**Query for GET /booking/orders:**
- `limit` (default 20), `offset` (default 0)
- `status` (optional): DRAFT | PENDING | ASSIGNED | DRIVER_ARRIVED | IN_PROGRESS | COMPLETED | CANCELLED
- `includeRoute` (optional): true – include route (polyline or coordinates) per order

**Cancel body:** `{ "reason"?: string }`.

**Review body:** `{ "rating": 1–5, "title"?, "comment"? }`.

---

### 4.6 Booking – Stats, Count, Earnings, Ride History with Route

| Method | Path                          | Auth | Description                              |
|--------|-------------------------------|------|------------------------------------------|
| GET    | /booking/stats                | Yes  | Aggregate stats for current user         |
| GET    | /booking/orders/summary       | Yes  | Same or subset (count + earnings)       |
| GET    | /booking/rides/count          | Yes  | Total completed ride count               |
| GET    | /booking/earnings             | Yes  | Total spent (user view) / earnings      |
| GET    | /booking/orders               | Yes  | Ride history; use status=COMPLETED + includeRoute=true for “history with route” |

**GET /booking/stats** response (suggested):
```json
{
  "data": {
    "totalRideCount": 42,
    "totalSpent": 528.00,
    "totalDistanceKm": 156.5,
    "completedCount": 42,
    "cancelledCount": 3
  }
}
```

**GET /booking/rides/count:**  
`{ "data": { "count": 42 } }` (only COMPLETED).

**GET /booking/earnings** (user = total spent):  
`{ "data": { "totalSpent": 528.00, "currency": "INR" } }`.

**GET /booking/orders** (ride history):
- Without `includeRoute`: list of orders with pickup/drop addresses, dates, amounts, status.
- With `includeRoute=true`: same plus `routePolyline` or `routeCoordinates` per order (for map).

**GET /booking/orders/:id?includeRoute=true:**  
Single order with full details + route for one ride.

---

## 5. Order Lifecycle (Flow)

1. **DRAFT** – User creates order (POST /booking/orders).
2. **PENDING** – User confirms (PUT …/confirm); backend notifies drivers (WebSocket).
3. **ASSIGNED** – Driver accepts; backend notifies user (WebSocket).
4. **DRIVER_ARRIVED** – Driver marks arrived at pickup; user notified.
5. **IN_PROGRESS** – Driver starts trip; optional live location (WebSocket).
6. **COMPLETED** – Driver ends trip; backend calculates final amount; user can pay and review.
7. **CANCELLED** – Anytime before/during; user or driver or system; store cancel_reason, cancelled_at, cancelled_by.

For stats/count/earnings use only **COMPLETED** orders (and optionally exclude refunded if you add that later).

---

## 6. WebSocket (Socket.IO)

- **URL:** Same host as API (e.g. `http://192.168.1.4:3000`).
- **Auth:** Handshake `auth: { token: "<accessToken>" }`. Validate JWT; attach userId to socket.

**Server → client events (user app):**

| Event                  | When                         | Payload (example)                    |
|------------------------|------------------------------|--------------------------------------|
| authenticated         | After valid token            | { userId }                           |
| auth_error            | Invalid/expired token        | { message }                          |
| user_connected        | User socket connected        | { userId }                           |
| order_created         | Order created (draft)        | { orderId, order }                  |
| finding_driver        | Order confirmed, searching   | { orderId }                          |
| order_assigned        | Driver assigned              | { orderId, driver, vehicle }         |
| order_status_update   | Status changed               | { orderId, status, ... }             |
| driver_arrived        | Driver at pickup             | { orderId, driverLocation }         |
| location_update       | Driver live location         | { orderId, lat, lng }                |
| order_cancelled       | Order cancelled              | { orderId, reason }                  |
| order_completed       | Trip completed               | { orderId, totalAmount }             |

**Client → server (user app):**
- `join_ride` – `{ orderId }` (user joins room for that order).
- `leave_ride` – `{ orderId }`.

Server: on confirm order, emit to driver app; on assign, emit to user socket (or user room).

---

## 7. Stats / Count / Earnings Implementation Notes

- **Total ride count:**  
  `SELECT COUNT(*) FROM order WHERE user_id = ? AND status = 'COMPLETED'`.

- **Total earnings (user = total spent):**  
  `SELECT COALESCE(SUM(total_amount), 0) FROM order WHERE user_id = ? AND status = 'COMPLETED'`.

- **Total distance:**  
  `SELECT COALESCE(SUM(final_distance_km), 0) FROM order WHERE user_id = ? AND status = 'COMPLETED'`.

- **Order history with route:**  
  - GET /booking/orders?limit=50&offset=0&status=COMPLETED&includeRoute=true  
  - For each order, include `route_polyline` or decoded coordinates from DB (or from order route table).  
  - GET /booking/orders/:id?includeRoute=true same, single order.

- **Summary endpoint:**  
  Return count + totalSpent + totalDistanceKm in one call to avoid multiple requests.

---

## 8. Response Shapes (Summary)

- **Single resource:** `{ "data": { ... } }`.
- **List:** `{ "data": [ ... ], "meta"?: { "total", "limit", "offset" } }`.
- **Stats/summary:** `{ "data": { totalRideCount, totalSpent, totalDistanceKm, ... } }`.
- **Count:** `{ "data": { "count": number } }`.
- **Error:** `{ "message": string, "statusCode": number }`.

---

## 9. Environment Variables

```env
NODE_ENV=development
PORT=3000
API_BASE_URL=http://192.168.1.4:3000
API_PREFIX=api/v1

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/taxi_db

# JWT
JWT_ACCESS_SECRET=your-access-secret
JWT_REFRESH_SECRET=your-refresh-secret
JWT_ACCESS_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# Redis (optional)
REDIS_URL=redis://localhost:6379

# Email (OTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
MAIL_FROM=noreply@yourapp.com

# CORS
CORS_ORIGIN=*
# Production: https://yourapp.com
```

---

## 10. Checklist (Nothing Missed)

- [ ] Health: GET /health
- [ ] Auth: register, send-otp, verify-otp, setup-password, login, login/send-otp, login/verify-otp, refresh, forget-password, reset-password
- [ ] Profile: GET/PUT /auth/profile
- [ ] Master: GET /booking/types, /vehicle-types, /package-types
- [ ] Locations: GET/POST /booking/locations
- [ ] Orders: POST (create), PUT :id/confirm, GET :id, GET (list with limit, offset, status, includeRoute), PUT :id/cancel, POST :id/review
- [ ] Stats: GET /booking/stats (totalRideCount, totalSpent, totalDistanceKm)
- [ ] Count: GET /booking/rides/count
- [ ] Earnings: GET /booking/earnings (totalSpent for user)
- [ ] Summary: GET /booking/orders/summary (count + earnings in one)
- [ ] Order history with route: GET /booking/orders?includeRoute=true and GET /booking/orders/:id?includeRoute=true
- [ ] Order statuses: DRAFT → PENDING → ASSIGNED → DRIVER_ARRIVED → IN_PROGRESS → COMPLETED; CANCELLED anytime
- [ ] Reviews: one per COMPLETED order, stored in `review` table
- [ ] WebSocket: auth, join_ride, leave_ride, all events (order_created, finding_driver, order_assigned, order_status_update, driver_arrived, location_update, order_cancelled, order_completed)
- [ ] DB: user, refresh_token, otp, vehicle_type, package_type, booking_type, user_location, order (with route_polyline or order_route), review
- [ ] Migrations and seeds for vehicle_type, package_type, booking_type
- [ ] CORS and firewall (e.g. scripts/allow-firewall-port-3000.ps1) for local device testing

This structure gives you a single reference to implement the full backend without missing order history, count, earnings, or route data.

