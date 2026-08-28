# Production APK — works on any device / any network

## What you need

1. **Backend deployed on the public internet with HTTPS** (not `192.168.x.x`, not `localhost`)
2. **Same API URL** in Customer app, Driver app, and Admin panel
3. **One build** — the API URL is embedded in the APK; users never configure anything

Test from your PC before building:

```text
https://YOUR-DOMAIN.com/api/v1/health   → must return 200
```

---

## Step 1 — Set your production URL (once)

Copy the example file and edit it:

```powershell
cd D:\taxiuser\taxi_customer_app
copy .env.production.example .env.production
notepad .env.production
```

Set your real domain (AWS API Gateway, your server, etc.):

```env
PRODUCTION_API_ORIGIN=https://abc123.execute-api.ap-south-1.amazonaws.com/prod
```

Use the **same URL** in the Driver app when you build that APK.

---

## Step 2 — Build the APK

```powershell
.\scripts\build-production-apk.ps1
```

Or pass the URL directly:

```powershell
.\scripts\build-production-apk.ps1 -ApiUrl "https://your-api.example.com"
```

Output:

```text
build\app\outputs\flutter-apk\app-release.apk
```

Install on any phone. Register and login work on **mobile data**, **any Wi‑Fi**, **any device** — accounts are stored on your server, not on the phone.

---

## Step 3 — Driver app (same URL)

```powershell
cd "D:\Taxi deiver\taxi-app"
.\scripts\build-release-apk.ps1 -ApiUrl "https://your-api.example.com"
```

---

## Local USB testing (debug only)

For testing on your PC Wi‑Fi while developing (not for distribution):

```powershell
.\scripts\run-on-phone.ps1 -DeviceId YOUR_DEVICE_ID
```

This uses your PC LAN IP — **only works on the same Wi‑Fi**, not for other networks.

---

## Backend not deployed yet?

Deploy `D:\Taxi Backend new\taxi-backend-main` to a cloud server with:

- HTTPS (nginx, ALB, or API Gateway)
- MongoDB on a private network
- Port 3000 reachable from the load balancer

See `D:\Taxi Backend new\taxi-backend-main\docs\API_GATEWAY.md` and `docs\DEPLOYMENT_URL_AUDIT.md`.

Until the backend has a public HTTPS URL, a universal APK **cannot** connect from other networks.
