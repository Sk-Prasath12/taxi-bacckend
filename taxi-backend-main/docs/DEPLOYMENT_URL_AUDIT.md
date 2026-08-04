# Deployment URL audit (Taxi platform)

Generated from repository scan. **Admin React app was not found in this workspace** — point it at the same `API_BASE_URL` as below (typically `VITE_API_BASE_URL` or `REACT_APP_API_URL`).

---

## 1. Current base URLs (by component)

| Component | Config source | Dev default | Production expectation |
|-----------|---------------|-------------|----------------------|
| **Customer Flutter** | `lib/config/env_config.dart` + `AppEndpoints` | `http://localhost:3000` or `DEVICE_API_HOST` | `API_BASE_URL=https://your-domain.com/api` |
| **Driver Flutter** | Same pattern | Same | Same |
| **Backend REST** | Express on `HOST:PORT` | `0.0.0.0:3000` | HTTPS via ALB/nginx/API Gateway → Node |
| **Socket.IO** | Same origin as API (no `/api` path) | `http://localhost:3000` | `https://your-domain.com` |
| **OSRM** | `OSRM_URL` / `OSRM_BASE_URL` | Docker `:5000` or backend `env.OSRM_URL` | Private service URL (not public Mongo) |
| **Admin website** | *Not in repo* | — | `https://your-domain.com/api` |

### URL roles (do not mix)

| Variable | Example | Used for |
|----------|---------|----------|
| `API_BASE_URL` | `https://api.example.com/api` | All REST (`/customers`, `/drivers`, `/admin`, …) |
| `SOCKET_BASE_URL` | `https://api.example.com` | Socket.IO (defaults to API origin if empty) |
| `OSRM_BASE_URL` | `https://api.example.com/osrm` or internal URL | Routing / distance |

Customer `ApiConfig.baseUrl` = **`apiBaseUrl`** (includes `/api`). Socket uses **`socketBaseUrl`**.

Driver `ApiConstants.baseUrl` = **origin**; `apiRestBase` = **`/api` prefix**; `socketUrl` = Socket origin.

---

## 2. Current Socket URLs

- **Customer:** `EnvConfig.socketBaseUrl` → `SocketService` (`lib/services/socket_service.dart`), JWT in `auth.token`.
- **Driver:** `ApiConstants.socketUrl` → `DriverSocketService`, JWT in `setAuth`, events `join`, `driver:online`, `new_ride`, etc.
- **Backend:** `src/socket/socket.ts` — CORS `origin: *`, transport `websocket`.

---

## 3. Admin API URL

- Backend mounts admin at **`/api/admin`** and **`/api/v1/admin`** (same router).
- Login: **`POST /api/v1/auth/login`** (admin user in MongoDB).
- Driver approval: **`PATCH /api/admin/drivers/:id/approve`**, **`POST /api/admin/drivers/approve-by-email`**.

Configure admin SPA: base = `https://your-domain.com/api`, auth = `/v1/auth/login`.

---

## 4. OSRM URL

- **Backend:** `OSRM_URL` in `.env.local` (required by `env.ts`).
- **Customer/Driver:** `OSRM_BASE_URL` or `OSRM_URL` in env; if empty, driver derives host from API (port 5000 only for non-HTTPS dev).
- **Docker:** `taxi_osrm` on host port `5000` (dev only; do not expose in production without auth).

---

## 5. Test / local URLs to remove from **production APK**

Found in **dev-only** paths (OK if not used in release):

| Location | Value |
|----------|--------|
| `.env.local` (customer/driver) | `localhost`, `192.168.0.100` |
| `env_config.dart` fallbacks | `localhost:3000`, LAN when `APP_ENV=development` |
| `http/*.http`, `README.md` | `192.168.1.16`, LAN examples |
| `test-quick.http` | `localhost:3000` |

**Release guard added:** `assertProductionApiConfigured()` in both apps — release build **throws** if `API_BASE_URL` is missing or LAN/localhost.

**Do not commit:** `.env.local`, `.env.production` with real secrets.

---

## 6. Production URL configuration (recommended)

```bash
# Flutter (both apps) — .env.production or dart-define
API_BASE_URL=https://api.yourdomain.com/api
SOCKET_BASE_URL=https://api.yourdomain.com
OSRM_BASE_URL=https://api.yourdomain.com   # or internal OSRM behind proxy
APP_ENV=production

# Backend — .env.production (server only, never in apps)
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
CORS_ORIGINS=https://admin.yourdomain.com,https://yourdomain.com
PUBLIC_API_URL=https://api.yourdomain.com
MONGO_URI=mongodb://user:pass@mongo-internal:27017/taxi_app?authSource=admin
# + JWT, SMTP, Razorpay, AWS S3 secrets
```

Build APK:

```powershell
cd taxi_customer_app
.\scripts\build-release-apk.ps1 -ApiUrl "https://api.yourdomain.com/api"

cd taxi-app
.\scripts\build-release-apk.ps1 -ApiUrl "https://api.yourdomain.com/api"
```

---

## 7. Backend deployment status

| Item | Status in repo |
|------|----------------|
| Listen `0.0.0.0` | **Yes** — `HOST` default `0.0.0.0`, `server.listen(PORT, HOST)` |
| HTTPS | **Not in Node** — terminate at nginx/ALB/API Gateway |
| CORS | **Configurable** — `CORS_ORIGINS` comma list |
| MongoDB public | **No** — docker exposes `27018` only for local dev; production should not publish Mongo |

---

## 8. API Gateway status

- **No Terraform/OpenAPI for AWS API Gateway in this workspace.**
- See `docs/API_GATEWAY.md` for mapping REST + WebSocket to the Node service.
- Use **HTTP API** or **REST API** + **VPC Link** to private ECS/EC2, or **HTTP proxy** to public ALB.

---

## 9. CORS status

- Dev: permissive when `CORS_ORIGINS` unset.
- Prod: set `CORS_ORIGINS` to admin + any web origins.
- Mobile apps are not CORS-limited; admin browser is.

---

## 10. Socket.IO status

- Implemented on same HTTP server as Express.
- Production: enable **sticky sessions** if scaling to multiple Node instances; use Redis adapter if needed (not in repo yet).
- JWT on handshake (`auth.token`) — implemented.

---

## 11. MongoDB status

- Local: `127.0.0.1:27018` via docker-compose.
- Apps **never** embed `MONGO_URI`.

---

## 12. Docker status

- `docker-compose.yml`: `app`, `mongo`, `osrm`; ports `3000`, `27018`, `5000`.
- Production: run app behind reverse proxy; **remove** public Mongo/OSRM ports or restrict by security group.

---

## 13. Customer APK status

- Central config: **Yes** (`EnvConfig` / `AppEndpoints`).
- Release script: **`scripts/build-release-apk.ps1`** (blocks LAN URLs).
- **Fix applied:** REST uses `/api` prefix via `ApiConfig.baseUrl` → `apiBaseUrl`.

---

## 14. Driver APK status

- Central config: **Yes** (`EnvConfig` / `ApiConstants`).
- Add **`scripts/build-release-apk.ps1`** (same as customer).
- Socket reconnect: **enabled** (`enableReconnection()`).

---

## 15. Ride flow / matching (backend)

Already implemented in `taxi-backend-main`:

- Ride create → `SEARCHING_DRIVER`
- Nearby online **approved** drivers (`nearby-drivers.util.ts`, geo + socket)
- Atomic accept (`acceptRideAtomically`)
- Admin driver approval without mandatory documents (account approve)

**E2E on real phones** still requires deployed HTTPS API + admin approval + physical device test (section 14 of your checklist).

---

## Next implementation order (remaining)

1. Deploy backend to EC2/ECS with TLS and set `CORS_ORIGINS`.
2. Wire **API Gateway** (see `docs/API_GATEWAY.md`) or ALB path rules.
3. Set production `.env` on server; keep Mongo private.
4. Build both APKs with public `API_BASE_URL`.
5. Point **Admin React** env to same API.
6. Two-phone + admin UAT on mobile data.
