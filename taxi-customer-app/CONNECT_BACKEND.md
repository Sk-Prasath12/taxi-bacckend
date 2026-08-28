# How to Connect the Taxi User App to the Backend

Follow these steps so the app talks to your real backend (API + WebSocket).

---

## 1. Run the backend

- Open the **backend** project (e.g. `taxi_app_backend` or wherever your Node server lives).
- Install and start it, e.g.:
  ```bash
  npm install
  npm run dev
  ```
- Ensure it listens on **port 3000** and exposes:
  - **REST API** at `http://<host>:3000/api/v1`
  - **Health** at `http://<host>:3000/health`
  - **WebSocket (Socket.IO)** at `http://<host>:3000`

---

## 2. Same network

- **Phone/tablet (physical device):** Connect the device to the **same Wi‑Fi** as the machine running the backend.
- **Emulator:** No extra step; use the special URLs below.

---

## 3. Set the app’s base URL

Edit **`lib/config/connection_config.dart`**:

- **Physical device on same Wi‑Fi:**  
  Set `physicalDeviceBaseUrl` to your **PC’s LAN IP** and port `3000`:
  ```dart
  static const String physicalDeviceBaseUrl = 'http://192.168.1.4:3000';
  ```
  To find your IP:
  - **Windows:** `ipconfig` → look for “IPv4 Address” under your Wi‑Fi adapter.
  - **Mac/Linux:** `ifconfig` or `ip addr` → use the inet address of your Wi‑Fi interface.

- **Android emulator:**  
  Use `10.0.2.2` to mean “host machine”:
  ```dart
  // Keep default or run app with:
  // flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  ```

- **iOS simulator:**  
  Use your machine’s LAN IP (e.g. `http://192.168.1.4:3000`) for devices on the same WiFi.

---

## 4. Open port 3000 (Windows firewall)

If the device cannot reach the backend, allow port 3000:

- **Option A:** Run as Administrator:
  - `api/scripts/allow-firewall-port-3000.bat`  
  or
  - `api/scripts/allow-firewall-port-3000.ps1`
- **Option B:** Manually add an inbound rule for TCP port **3000** in Windows Defender Firewall.

---

## 5. Verify connection

1. On the **phone browser** (or emulator’s browser), open:
   ```text
   http://<your-base-url>/health
   ```
   Example: `http://192.168.1.4:3000/health`  
   You should see a successful response (e.g. 200 OK).
2. In the **app**, go through **Sign up** or **Login**. The app uses the same base URL for auth; if health works and the device is on the same network, login should reach the backend.

---

## 6. Run the Flutter app

```bash
cd c:\Users\manimaran\OneDrive\Desktop\taxi_user
flutter pub get
flutter run
```

For Android emulator with a custom URL:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

---

## Quick checklist

| Step | Done |
|------|------|
| Backend running (`npm run dev`) on port 3000 | ☐ |
| Device and backend on same Wi‑Fi (or emulator) | ☐ |
| `connection_config.dart` uses correct IP/host and `:3000` | ☐ |
| Firewall allows TCP 3000 (if on physical device) | ☐ |
| `http://<base-url>/health` works in browser | ☐ |
| App login/signup works | ☐ |

Once these are done, the app is configured to use the backend for auth, booking, orders, and real-time updates (WebSocket).

---

## What the app expects from the backend

- **Health:** `GET /health` → 200 OK.
- **Auth:** `POST /auth/register`, `/auth/register/verify-otp`, `/auth/setup-password`, `/auth/login`, `/auth/login/verify-otp`, `/auth/forget-password`, `/auth/reset-password` (see `api/BACKEND_STRUCTURE.md`).
- **Booking:**  
  - `GET /booking/vehicle-types` → `{ "data": [ { "id", "name", "slug", ... } ] }`.  
  - `POST /booking/orders` with body `pickupAddress`, `pickupLat`, `pickupLng`, `dropAddress`, `dropLat`, `dropLng`, `vehicleTypeId`, `paymentMode`.  
  - `PUT /booking/orders/:id/confirm`, `GET /booking/orders`, `GET /booking/orders/:id`, `PUT /booking/orders/:id/cancel`, `POST /booking/orders/:id/review` (review body: `rating`, optional `title`, `comment`).  
  - `GET /booking/stats` → `{ "data": { "totalRideCount", "totalSpent", "totalDistanceKm" } }` (or snake_case equivalents).  
  - `GET /booking/locations`, `POST /booking/locations`.
- **WebSocket (Socket.IO):** Same host, auth with `auth: { token: "<accessToken>" }`. User emits `join_ride` / `leave_ride` with `{ orderId }`. Server emits `order_assigned`, `location_update` (payload with `lat`, `lng`) to the user.

