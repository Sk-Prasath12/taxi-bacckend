# Customer App — Persistent Login & Auto-Redirect

## Behaviour

1. **First login** — email/password (or OTP registration) → JWT saved in `CustomerSessionStore` → Ride Booking Home (`/home`).
2. **App reopen** — `AppBootstrapScreen`:
   - Restores session from local storage
   - Validates profile via `GET /api/customers/profile`
   - Refreshes access token if expired (`POST /api/v1/auth/refresh`) when refresh token exists
   - Fetches active ride via `GET /api/customers/rides/active`
   - Routes to home, driver-searching, ride-tracking, or payment screen
3. **Logout** — clears tokens, profile cache, active ride cache → Login screen.
4. **Manual logout flag** — session not restored until next successful login.

## Stored locally (`CustomerSessionStore`)

| Key | Purpose |
|-----|---------|
| `access_token` | JWT for API + socket |
| `refresh_token` | Token rotation (when backend returns it) |
| `customer_id` | User id |
| `email`, `name`, `phone` | Profile display |
| `is_logged_in` | Login status |
| `login_at`, `last_active_at` | Session timestamps |
| `device_id` | Same-device session |
| `profile_json` | Cached profile from API |

## Startup routing (`StartupRouter`)

| Active ride status | Screen |
|--------------------|--------|
| None | `/home` |
| `PENDING_CONFIRMATION` | `/booking-summary` |
| `SEARCHING_DRIVER` | `/driver-searching` |
| Assigned / in-trip statuses | `/ride-tracking` |
| `COMPLETED` + online payment pending | `/ride-payment` |

## Key files (customer app)

| File | Role |
|------|------|
| `lib/presentation/pages/auth/app_bootstrap_screen.dart` | App entry + session restore |
| `lib/services/customer_session_store.dart` | Secure local session |
| `lib/services/customer_auth_manager.dart` | Bootstrap, refresh, logout |
| `lib/services/startup_router.dart` | Route by active ride |
| `lib/services/active_ride_store.dart` | Local active ride cache |
| `lib/services/session_bootstrap.dart` | Post-login socket + FCM |

## Backend

- Login: `POST /api/customers/login` → `{ token, refreshToken?, user }`
- Refresh: `POST /api/v1/auth/refresh` → `{ data: { accessToken } }`
- Profile: `GET /api/customers/profile`
- Active ride: `GET /api/customers/rides/active`

## Test

1. Log in once as customer
2. Kill app / close browser tab
3. Reopen → should land on `/home` without login
4. Book a ride, confirm, go to driver-searching
5. Kill app → reopen → should restore driver-searching or tracking
6. Logout from drawer → next open shows login
