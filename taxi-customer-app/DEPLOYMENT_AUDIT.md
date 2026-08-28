# Deployment audit — Taxi platform (scan + production plan)

**Scan date:** 2026-07-29  
**Repos in workspace:** Customer Flutter, Driver Flutter, Node backend. **Admin React** and **AWS API Gateway** configs were **not found** in this workspace — point them at the same public API below.

---

## 1. Current base URLs (before production `.env`)

| Component | Current source | Typical value today |
|-----------|----------------|---------------------|
| Customer REST | `EnvConfig.apiBaseUrl` | `http://192.168.0.100:3000/api` (via `DEVICE_API_HOST` + `.env.local`) |
| Customer Socket | `EnvConfig.socketBaseUrl` | Same origin as API (port 3000) |
| Driver REST | `ApiConstants.apiRestBase` | Same LAN host + `/api` |
| Driver Socket | `ApiConstants.socketUrl` | Same LAN origin |
| Admin (expected) | Not in repo | Should be `VITE_API_URL` / `REACT_APP_API_URL` → `https://api.yourdomain.com/api` |
| OSRM (customer) | `EnvConfig.osrmBaseUrl` or public fallback | `https://router.project-osrm.org` |
| OSRM (driver) | `ApiConstants.osrmUrl` | API host `:5000` or env |
| Backend HTTP | `PORT` + `HOST` | Docker `3000:3000`, was implicit localhost bind |

**Hardcoded / test URLs found (customer):**

- `lib/config/env_config.dart` — dev fallbacks `localhost`, `DEVICE_API_HOST` (dev only after fix)
- `lib/domain/services/osrm_service.dart` — was `192.168.1.4:5001` (**fixed** → env + public OSRM)
- Docs/scripts: `192.168.x.x`, `CONNECT_BACKEND.md`, `sync-lan-ip.ps1` (dev only)

**Hardcoded / test URLs found (driver):**

- `lib/config/env_config.dart` — dev LAN fallbacks
- `.env.local` — `DEVICE_API_HOST=192.168.0.100:3000`
- Embedded admin API in driver app uses same `apiRestBase` (not a separate admin host)

---

## 2. Current Socket URLs

| App | File | Connection |
|-----|------|------------|
| Customer | `lib/services/socket_service.dart` | `ConnectionConfig.webSocketUrl` → `EnvConfig.socketBaseUrl` |
| Driver | `lib/services/driver_socket_service.dart` | `ApiConstants.socketUrl` |
| Driver (customer flow) | `customer_socket_service.dart` | `ApiConstants.socketUrl` |

Socket auth: JWT via `setAuth({'token': ...})`. Driver has `enableReconnection()`; customer reconnects on disconnect after 3s.

---

## 3. Admin API URL

- Backend mounts: `/api/admin`, `/api/v1/admin` (`src/app.ts`).
- **Admin website not in workspace** — configure its env to:
  - `https://api.yourdomain.com/api` (REST)
  - WebSocket origin: `https://api.yourdomain.com` (if admin uses live rides)

---

## 4. OSRM URL

| Layer | URL |
|-------|-----|
| Backend | `OSRM_URL` in backend `.env` (required in schema) |
| Customer app | `OSRM_BASE_URL` / `OSRM_URL` → else public OSRM |
| Driver app | `OSRM_BASE_URL` or derived from API host |
| Docker | `osrm` service port `5000` (local compose only) |

Production: expose OSRM behind same domain (reverse proxy `/osrm`) or dedicated routing host.

---

## 5. Test URLs to remove from **production APK**

Do **not** ship release builds with:

- `localhost` / `127.0.0.1`
- `192.168.*` / `10.*` (except emulator define in **debug** only)
- `ngrok` / temporary tunnels
- `DEVICE_API_HOST` (ignored when `APP_ENV=production` or release mode + HTTPS `API_BASE_URL`)

Release builds must use:

```text
--dart-define=APP_ENV=production
--dart-define=API_BASE_URL=https://api.yourdomain.com/api
--dart-define=SOCKET_BASE_URL=https://api.yourdomain.com
```

Scripts: `scripts/build-release-apk.ps1` (customer + driver).

---

## 6. Production URL configuration (implemented)

Central parsing: `lib/config/app_endpoints.dart` (customer + driver copies).

| Variable | Purpose |
|----------|---------|
| `API_BASE_URL` | REST root, e.g. `https://api.yourdomain.com/api` |
| `SOCKET_BASE_URL` | Socket.IO origin, e.g. `https://api.yourdomain.com` |
| `OSRM_BASE_URL` | Routing server |
| `APP_ENV` | `development` \| `staging` \| `production` |

Example files:

- `.env.development.example`
- `.env.staging.example`
- `.env.production.example`
- Backend: `taxi-backend-main/.env.example`

---

## 7. Backend deployment status

| Item | Status |
|------|--------|
| Docker Compose | Present — `app`, `mongo`, `osrm`; API on `0.0.0.0:3000` via port map |
| Listen address | **Updated** — `HOST=0.0.0.0` in `server.ts` |
| MongoDB | Docker internal + `27018` published ( **do not expose 27018 on public VPS** ) |
| HTTPS / SSL | **Your infra** — nginx/ALB/API Gateway in front of Node |
| Public internet | **Not verified** — requires deployed host + DNS |

---

## 8. API Gateway status

**No `execute-api` / Gateway config found in scanned repos.**

If you already have API Gateway:

- Map stage URL to Node (or Lambda if migrated).
- Enable WebSocket API **or** sticky sessions to same Node for Socket.IO.
- Use **one** public base URL for mobile apps and admin.

Provide your Gateway URL to bake into `.env.production`.

---

## 9. CORS status

| Before | After |
|--------|-------|
| `app.use(cors())` — open | `CORS_ORIGINS` comma list in backend `.env` |

Set e.g. `CORS_ORIGINS=https://admin.yourdomain.com,https://yourdomain.com`

Mobile apps are not browser CORS-limited; admin React **is**.

---

## 10. Socket.IO status

- Initialized on same HTTP server (`initializeSocketServer(server)`).
- Production: must be reachable at `SOCKET_BASE_URL` (same host as API is typical).
- Behind reverse proxy: enable WebSocket upgrade headers.

---

## 11. MongoDB status

- Local Docker: `mongo:27017` internal, credentials via `MONGO_URI`.
- Production: Atlas or private subnet; **never** public `27017`.

---

## 12. Docker status

- Dev stack OK for local QA.
- Production: use `docker-compose.prod.yml` pattern (no public mongo port), secrets via env/SSM, TLS at edge.

---

## 13. Customer APK status

| Item | Status |
|------|--------|
| Central config | **Done** — `EnvConfig` + `AppEndpoints` |
| Dev server UI | Hidden when `APP_ENV=production` or HTTPS API |
| Release build script | `scripts/build-release-apk.ps1` |
| E2E on 2 phones + different networks | **Blocked until public HTTPS API is live** |

---

## 14. Driver APK status

Same as customer; script at `D:\Taxi deiver\taxi-app\scripts\build-release-apk.ps1`.

Ride matching / atomic accept: implemented in backend (`nearby-drivers`, driver-ride service) from prior work — re-verify on staging after public deploy.

---

## Implementation order (remaining)

1. **Deploy backend** with HTTPS + `HOST=0.0.0.0` + private MongoDB.
2. **Wire API Gateway** (if used) to same routes as `app.ts`.
3. Copy `.env.production.example` → `.env.production` with **your real domain**.
4. Build APKs with `build-release-apk.ps1 -ApiUrl "https://..."`.
5. Point **Admin React** env to same `API_BASE_URL`.
6. Run **§14 production test** (2 phones, different networks, admin on PC).

---

## Acceptance criteria (§16)

Cannot be marked complete until a **public** backend URL is deployed and the full Customer → Driver → Admin ride flow is tested on physical devices. Code/config changes above remove LAN/test URLs from **release** builds; **you must supply the live API hostname** (AWS/API Gateway or VPS).

See also: `PRODUCTION_APK.md`.
