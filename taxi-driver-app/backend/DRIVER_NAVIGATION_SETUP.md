# Driver GPS Navigation & Customer Sync

## Flow

```
Accept ride → ActiveRidePage (live nav)
  → GPS stream (real device, ~5m filter)
  → OSRM route to pickup
  → WebSocket driver_location + driver_location_update (lat, lng, speed, heading)
  → Arrived (geofence ~120m) → OTP verify → Picked up → In transit (route switches to drop)
  → Complete at drop (~150m) → RidePaymentPage → Dashboard
```

## New / updated files

| File | Purpose |
|------|---------|
| `lib/services/driver_location_service.dart` | Real GPS stream, speed, heading |
| `lib/services/osrm_service.dart` | OSRM routes (Docker `:5000`) |
| `lib/services/active_ride_store.dart` | Hive persistence for ride resume |
| `lib/drive_page/active_ride_page.dart` | Live map, ETA, geofence actions |
| `lib/drive_page/ride_payment_page.dart` | Payment gate before ride close |
| `lib/utils/ride_navigation_utils.dart` | Distance / ETA helpers |

## Customer app sync (same backend)

| Driver action | API | Customer receives |
|---------------|-----|-------------------|
| Accept | `POST /drivers/rides/:id/accept` | `ride_accepted`, `ride_status_update` |
| Arrived | `POST .../arrived` | `ride_status_update` |
| OTP | `POST .../verify-otp` | `ride_status_update` (STARTED) |
| In transit | `POST .../in-transit` | `ride_status_update` |
| Complete | `POST .../dropped` | `COMPLETED` + invoice |
| GPS | Socket `driver_location` | Live marker on customer map |

## Prerequisites

- OSRM: `http://localhost:5000` (Docker `taxi_osrm`)
- Backend: `http://localhost:3000`
- Location permission granted on device/browser
- Customer app `API_BASE_URL` = same host as driver app

## Test

1. Driver: ON DUTY → accept ride → navigation opens automatically
2. Move toward pickup → **I Reached Pickup** enables near pickup
3. Enter customer OTP → verify → start trip to drop
4. Complete at drop → payment screen
5. Cash: close immediately; Online: wait for customer payment poll
6. Kill driver app mid-ride → reopen → resumes active ride from dashboard
