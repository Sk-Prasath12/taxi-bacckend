## Taxi App Backend – End‑to‑End Flow

### 1. Components

- **API server**
  - Auth & users
  - Rider APIs
  - Driver APIs
  - Admin APIs
- **WebSocket server**
  - Real‑time driver location and ride status events.
- **Database**
  - Relational DB (Postgres/MySQL).
- **Background jobs**
  - Driver matching, timeouts, notifications.

---

### 2. Data Model (main tables)

- **`users`**
  - `id`, `name`, `phone`, `email`, `password_hash`
  - `role`: `RIDER` \| `DRIVER` \| `ADMIN`
  - `rating`, `created_at`, `updated_at`

- **`drivers`**
  - `id`, `user_id` (FK `users.id`)
  - `status`: `OFFLINE` \| `ONLINE` \| `ON_TRIP`
  - `vehicle_type_id`, `vehicle_number`
  - `current_lat`, `current_lng`, `last_seen_at`

- **`vehicle_types`**
  - `id`, `name` (`Small` / `Medium` / `Large`)
  - `slug`, `base_fare`, `per_km`, `per_min`

- **`ride_orders`**
  - `id`
  - `rider_id` (FK `users.id`)
  - `driver_id` (FK `users.id`, nullable until assigned)
  - `status`:
    - `DRAFT` → `PENDING` → `ASSIGNED` → `DRIVER_ARRIVED` → `IN_PROGRESS` → `COMPLETED`
    - `CANCELLED` (allowed anytime)
  - `pickup_address`, `pickup_lat`, `pickup_lng`
  - `drop_address`, `drop_lat`, `drop_lng`
  - `vehicle_type_id`
  - `payment_mode`: `CASH` \| `UPI` \| `CARD`
  - `distance_km_est`, `duration_sec_est`
  - `fare_estimate`, `fare_final`
  - `created_at`, `accepted_at`, `arrived_at`, `started_at`, `completed_at`, `cancelled_at`

- **`ride_locations`** (optional tracking)
  - `id`, `order_id`, `lat`, `lng`, `recorded_at`

- **`payments`**
  - `id`, `order_id`, `amount`, `currency`
  - `status`: `PENDING` \| `PAID` \| `FAILED`
  - `provider`: `STRIPE`, `RAZORPAY`, etc.
  - `provider_ref`, `created_at`, `paid_at`

- **`driver_sessions`**
  - `id`, `driver_id`
  - `is_online`, `started_at`, `ended_at`, `last_heartbeat_at`

---

### 3. Auth & User APIs

- **POST `/auth/register`**
  - Body: `name`, `phone`, `password`, `role`
  - Creates user, returns JWT.

- **POST `/auth/login`**
  - Body: `phone`, `password`
  - Returns JWT for subsequent calls.

---

### 4. Rider Flow (HTTP)

#### 4.1 Estimate fare

- **POST `/rides/estimate`**
  - Body:
    - `pickupLat`, `pickupLng`
    - `dropLat`, `dropLng`
    - `vehicleTypeId`
  - Server:
    - Calls OSRM for route.
    - Computes `distance_km_est`, `duration_sec_est`.
    - Calculates `fare_estimate` using `vehicle_types` pricing.
  - Response:
    - `distanceKm`, `durationSec`, `fareEstimate`, `routePoints`.

#### 4.2 Create ride order

- **POST `/rides`**
  - Called from `PaymentSelectionScreen` when user taps **CONFIRM BOOKING**.
  - Body:
    - `pickupAddress`, `pickupLat`, `pickupLng`
    - `dropAddress`, `dropLat`, `dropLng`
    - `vehicleTypeId`
    - `paymentMode` (`CASH` / `UPI` / `CARD`)
  - Server:
    - Creates `ride_orders` row with:
      - `status = PENDING`
      - `fare_estimate`, `distance_km_est`, `duration_sec_est`.
  - Response:
    - `orderId`, `status: PENDING`.

#### 4.3 Confirm ride & start driver matching

- **POST `/rides/{id}/confirm`**
  - Server:
    - Validates order belongs to rider, status `PENDING`.
    - Triggers matching algorithm (see section 5).
    - Returns initial status:
      - `status: FINDING_DRIVER` or `ASSIGNED`.

#### 4.4 Get ride details

- **GET `/rides/{id}`**
  - Response includes:
    - Basic order data (`pickup`, `drop`, `status`, times).
    - Assigned driver + vehicle details (if any).
    - `fare_estimate`, `fare_final` (if completed).

---

### 5. Driver Matching Flow

#### 5.1 Driver online/offline

- **POST `/drivers/me/status`**
  - Body: `status: ONLINE | OFFLINE`
  - Server:
    - Updates `drivers.status` and `driver_sessions`.

#### 5.2 Matching algorithm (MVP)

When `/rides/{id}/confirm` is called:

1. Find candidate drivers:
   - `drivers.status = ONLINE`
   - Within configured radius of pickup.
   - Matching `vehicle_type_id`.
2. Select one driver:
   - Nearest or highest rating.
3. Assign driver:
   - Update `ride_orders.driver_id`.
   - Set `status = ASSIGNED`, `accepted_at = now`.
4. Notify via WebSocket:
   - To driver: `order_assigned` with full ride info.
   - To rider: `order_status_update` with `status = ASSIGNED`.

If no drivers available:

- Keep status `PENDING` or `FINDING_DRIVER`.
- Optionally retry in background or notify rider.

---

### 6. WebSocket Events

Namespace example: `/ride`.

#### 6.1 Client → Server

- `join_ride { orderId }`
- `leave_ride { orderId }`
- `driver_location_update { orderId, lat, lng }` (driver app)
- `driver_arrived { orderId }`
- `start_trip { orderId }`
- `complete_trip { orderId }`
- `cancel_ride { orderId, reason }`

#### 6.2 Server → Client

- `order_created`
- `finding_driver`
- `order_assigned`
- `driver_arrived`
- `location_update`
- `order_status_update`
- `order_cancelled`
- `order_completed`

#### 6.3 Timeline

1. Rider confirms ride:
   - `ride_orders.status = PENDING`.
   - Matching starts; emit `finding_driver`.
2. Driver assigned:
   - `status = ASSIGNED`, `accepted_at` set.
   - Emit `order_assigned` to driver and `order_status_update` to rider.
3. Driver sends `driver_location_update`:
   - Backend broadcasts `location_update` to rider room.
4. Driver reaches pickup:
   - Driver app emits `driver_arrived { orderId }`.
   - Backend sets `status = DRIVER_ARRIVED`, `arrived_at = now`.
   - Emits `driver_arrived` to rider.
5. Trip starts:
   - On “Arrived” button press (driver or rider side):
     - Emit `start_trip { orderId }`.
     - Backend sets `status = IN_PROGRESS`, `started_at = now`.
6. Trip completed:
   - Driver taps “End trip”:
     - Emit `complete_trip { orderId }`.
     - Backend:
       - Calculates distance/time from `ride_locations` or OSRM.
       - Computes `fare_final`.
       - Sets `status = COMPLETED`, `completed_at = now`.
       - Emits `order_completed`.

---

### 7. Payment Flow

#### 7.1 Cash / simple UPI

- `payment_mode = CASH`:
  - After `COMPLETED`, a `payments` row is created with `status = PENDING`.
  - Driver confirms cash collection:
    - **POST `/payments/{orderId}/confirm-cash`**
    - Backend sets `payments.status = PAID`.

- `payment_mode = UPI` (MVP):
  - Treat initially like `CASH` but the app shows UPI QR / handle.
  - When driver confirms receipt, call same `confirm-cash` endpoint.

#### 7.2 Card (gateway)

1. **POST `/payments/create`**
   - Body: `orderId`, `amount`.
   - Backend:
     - Creates `payments` row.
     - Creates payment intent/order with gateway.
     - Returns client secret / order id to app.
2. Client completes card payment using provider SDK.
3. Provider webhook `/payments/webhook`:
   - Validates signature.
   - Updates `payments.status = PAID`.
   - Optionally emits `payment_status_update` over WebSocket.

---

### 8. Bill / Trip Summary

- **GET `/rides/{id}/bill`**
  - Backend assembles:
    - Pickup / drop addresses.
    - Distance, time, fare breakdown.
    - `payment_mode`, `payment_status`.
  - Used by Flutter `TripBillScreen` to display the bill.

---

### 9. Admin APIs (minimal)

- **GET `/admin/rides`**
- **GET `/admin/rides/{id}`**
- **GET `/admin/drivers`**
- **PUT `/admin/rides/{id}`** – manual override of ride status / driver.

---

### 10. Notes for Implementation

- Recommended stack:
  - Node (NestJS/Express) or Django/Laravel with:
    - JWT auth middleware.
    - ORM for the data model above.
    - WebSocket gateway for real‑time events.
- This file defines the contract for your frontend:
  - Flutter screens like `PaymentSelectionScreen`, `LiveTrackingScreen`, and `TripBillScreen` should use these endpoints and socket events.

