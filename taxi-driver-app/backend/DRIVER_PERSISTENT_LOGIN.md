# Driver Persistent Login

## Behaviour

1. **First login** — email/password → JWT + refresh token saved in Hive (`driver_session_box`).
2. **App reopen** — `AuthWrapper` runs `bootstrapSession()`:
   - Restores token from local storage
   - Refreshes access token if expired (`POST /api/v1/auth/refresh`)
   - Validates with `GET /api/v1/driver/profile`
   - Opens **Dashboard** (skips login/OTP/register)
3. **Logout** — clears tokens, profile cache, active ride, on-duty flag.
4. **On-duty restore** — if driver was online before close, dashboard re-enables listener + WebSocket.

## Stored locally

| Key | Purpose |
|-----|---------|
| `access_token` | JWT for API |
| `refresh_token` | Token rotation |
| `driver_id` | Driver Mongo id |
| `email`, `name`, `phone` | Profile |
| `is_logged_in` | Session flag |
| `was_on_duty` | Online restore |
| `login_at`, `last_active_at` | Session audit |
| `device_id` | Same-device session |
| `profile_json` | Cached profile |

## Backend

- Driver login: `POST /api/drivers/login` → `{ token, refreshToken, user }`
- Refresh: `POST /api/v1/auth/refresh` → `{ data: { accessToken } }`

## Files

- `lib/services/driver_session_store.dart`
- `lib/authentication_page/auth_service.dart`
- `lib/authentication_page/auth_wrapper/auth_wrapper.dart`
- `lib/utils/jwt_utils.dart`
