# Customer + Driver app integration (live ride flow)

One Flutter project, two roles. Both use Docker API on **port 3000**.

## Architecture

1. **Customer app** → Request ride → **Confirm** → server emits `new_ride`
2. **Driver app** → Ride Requests (WebSocket + API) → Accept → Active Ride
3. **Customer app** → live status via WebSocket (`ride_accepted`, `ride_status_update`)

## Prerequisites

- Docker: `taxi_app_backend` + `taxi_app_mongo` on port 3000
- Health: `http://localhost:3000/api/v1/health`
- Zone seed if needed: `scripts/seed-chennai-zone.mongodb.js`
- Driver verified: `sridharshini@yopmail.com`

## Test with two browsers (recommended)

### Browser 1 — Customer app

1. `flutter run -d chrome`
2. Home → **Customer App — Book Ride**
3. Login (`sk2011@yopmail.com` / `Sk@123456`)
4. Tap **1. Request Ride**
5. Tap **2. Confirm & send to drivers** (required)
6. Choose **Cash** or **Online** payment before Request
7. Watch **Live ride status** update when driver accepts and completes
8. After **Ride completed**: Cash = pay driver; Online = **Create Razorpay order**

### Browser 2 — Driver app

1. Chrome Incognito or Edge → same app URL
2. Home → **Driver App — Sign In**
3. `sridharshini@yopmail.com` / `sri@123456`
4. Drawer → **Ride Requests** (goes **Online** automatically; uses test GPS near pickup on web)
5. Accept ride → Active Ride: Arrived → OTP → Picked up → **In transit** → Dropped

## Accounts

| Role     | Email                     | Password    |
|----------|---------------------------|-------------|
| Customer | sk2011@yopmail.com        | Sk@123456   |
| Driver   | sridharshini@yopmail.com  | sri@123456  |

## HTTP alternative

Run [e2e-ride-flow.http](e2e-ride-flow.http) for API-only testing.

## Common issues

| Issue | Fix |
|-------|-----|
| No ride on driver | Customer must tap **Confirm** |
| Pickup zone inactive | Seed operational zone |
| Active ride blocks request | Cancel on customer screen or customer-flow.http |
