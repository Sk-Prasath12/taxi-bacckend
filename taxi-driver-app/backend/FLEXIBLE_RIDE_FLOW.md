# Flexible ongoing ride management

## Driver app (no geo-fence)

All action buttons stay visible on the active ride screen:

| Button | Action |
|--------|--------|
| ARRIVED | Marks arrived; backend generates **pickup OTP** |
| START RIDE (verify pickup OTP) | Driver enters customer pickup OTP |
| PICKUP CONFIRM | Passenger onboard |
| START RIDE (to drop) | In transit to drop |
| DROP REACHED | Records actual GPS drop + live distance fare |
| VERIFY DROP OTP | Driver enters customer **drop OTP** |
| COMPLETE RIDE | Opens payment screen |

Live GPS distance/duration/fare shown while trip is active.

## Customer app

- **Pickup OTP** shown when driver arrives
- **Drop OTP** shown after drop reached (same OTP card, label changes)
- Realtime socket updates for status and payment

## Backend (Docker)

Apply patch:

```bash
sh backend/docker-patch/apply-flexible-ride.sh
```

New driver endpoints (same `/api/drivers/rides/:rideId/...` pattern):

- `POST .../verify-drop-otp` `{ otp }`
- `POST .../cash-received`
- `POST .../complete`
- `POST .../dropped` body: `{ fare, lat, lng, actual_distance_km, duration_min }`

## Payment

1. Drop OTP verified → payment pending
2. **Cash**: driver taps CASH RECEIVED → COMPLETE RIDE → home (stays online)
3. **Razorpay**: customer pays → driver COMPLETE RIDE

## Socket events

`ride_accepted`, `driver_arrived`, `pickup_otp_generated`, `pickup_otp_verified`, `trip_started`, `gps_tracking_started`, `drop_reached`, `drop_otp_generated`, `drop_otp_verified`, `payment_pending`, `payment_success`, `ride_completed`
