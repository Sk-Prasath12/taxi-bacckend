# Deploy taxi backend on Vercel

## Why apps were not connecting

1. **Flutter apps had wrong URLs** — Driver had `REPLACE_WITH_YOUR_API`, Customer had an expired Cloudflare tunnel.
2. **Vercel was not serving the API** — `/api/v1/health` returned Vercel HTML (404 or login page), not JSON.
3. **Socket.IO** — Real-time ride updates need a **always-on server** (Railway, Render, Fly.io, VPS). Vercel serverless runs **REST only**.

## Vercel project settings

In [Vercel Dashboard](https://vercel.com) → your project → **Settings**:

| Setting | Value |
|---------|--------|
| **Root Directory** | `taxi-backend-main` |
| **Framework Preset** | Other |
| **Build Command** | `npm run build` |
| **Output Directory** | (leave empty) |
| **Install Command** | `npm install` |

**Deployment Protection** → disable for Production (or mobile apps cannot call preview URLs like `…-drjznp3aw-….vercel.app`).

## Environment variables (required)

Copy from `.env.example` / your local `.env.local` into Vercel → **Settings → Environment Variables**:

- `MONGO_URI`
- `JWT_ACCESS_SECRET`, `JWT_REFRESH_SECRET`
- `SMTP_*` (all SMTP fields)
- `OSRM_URL` (e.g. `https://router.project-osrm.org`)
- `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`
- Optional: `CORS_ORIGINS`, `PUBLIC_API_URL=https://taxi-bacckend.vercel.app`

Redeploy after adding variables.

## Verify deployment

Open in a browser or curl:

```text
https://taxi-bacckend.vercel.app/api/v1/health
```

Expected:

```json
{"success":true,"message":"Service healthy",...}
```

If you see HTML or 404, the deploy is not correct yet.

## Flutter apps (Driver + Customer)

Both use `assets/env/app.env`:

```env
API_BASE_URL=https://taxi-bacckend.vercel.app/api
SOCKET_BASE_URL=https://taxi-bacckend.vercel.app
```

Rebuild APKs after any URL change:

```powershell
# Driver
cd "D:\Taxi deiver\taxi-app"
.\scripts\build-release-apk.ps1 -ApiUrl "https://taxi-bacckend.vercel.app"

# Customer
cd "D:\taxiuser\taxi_customer_app"
.\scripts\build-production-apk.ps1 -ApiUrl "https://taxi-bacckend.vercel.app"
```

Install the new APK on each phone. Old APKs keep the old URL baked in.

## Real-time rides (Socket.IO)

For driver/customer live location and ride events, deploy the **same codebase** to Railway or Render:

- Use `npm run start:prod` (long-running Node process)
- Set the same env vars
- Point `SOCKET_BASE_URL` in both apps to that host

REST on Vercel + Socket on Railway is possible but both apps must use the **same** `SOCKET_BASE_URL` as the socket server.

## Share APK install links (any Android device)

Use the **`apk-downloads`** folder in the repo root:

```powershell
cd "D:\Taxi Backend new\apk-downloads"
.\deploy.ps1
```

Vercel prints a URL like `https://taxi-apk-downloads.vercel.app`. Share that link.

| App | Download path |
|-----|----------------|
| Driver | `/downloads/taxi-driver.apk` |
| Customer | `/downloads/taxi-customer.apk` |

Rebuild APKs **after** the backend health check passes, so the baked-in API URL is correct.

**Important:** `MONGO_URI` on Vercel must be **MongoDB Atlas** (cloud). Local `127.0.0.1` only works on your PC, not on Vercel.
