# Why login errors repeat — and how to fix them permanently

## The problem in simple words

Your app is **two parts**:

```
[Phone APK]  ----internet---->  [Server on your PC in Docker]
   login/register                    MongoDB saves users here
```

If the phone cannot reach the server, you see errors like:

- `No host specified in URI`
- `Cannot reach server`
- `Failed host lookup`
- `Server is offline`

These look similar but have **different causes**. Fixing one without the other makes the problem **come back**.

---

## The 3 causes (why it repeats)

### Cause 1 — Wrong type of app build

| What you ran | Works where | Problem |
|--------------|-------------|---------|
| `flutter run` (debug) | USB + same Wi-Fi only | Uses LAN IP; fails on mobile data |
| Old release APK | Needs exact URL baked in | URL dead after tunnel restart |
| **Release APK** built after **start-stack** | Any network | Correct way |

**Permanent rule:** For other people’s phones, always use **`app-release.apk`**, never debug `flutter run`.

---

### Cause 2 — Server not running on your PC

The APK points to your **public HTTPS URL**. That URL only works if **all three** are running on your PC:

1. **Docker** → `taxi_app_backend`, `taxi_app_mongo`, `taxi_osrm`
2. **cloudflared** → public HTTPS tunnel
3. **PC is on** and connected to internet

If you **restart PC**, **close cloudflared**, or **stop Docker** → every phone fails login until you start again.

**Permanent fix:** Run after every reboot:

```powershell
cd D:\taxiuser\taxi_customer_app
.\scripts\start-stack.ps1
```

Optional — auto-start on Windows login:

```powershell
.\scripts\install-auto-start.ps1
```

---

### Cause 3 — Tunnel URL changed but APK is old

Cloudflare **free quick tunnel** gives a new URL like:

`https://something-random.trycloudflare.com`

When cloudflared **restarts**, the URL **changes**. The old APK still has the **old URL** → login fails forever until you **rebuild APK**.

**Permanent fix when URL changes:**

```powershell
.\scripts\start-stack.ps1          # get new URL
.\scripts\build-production-apk.ps1 # rebuild APK with new URL
```

Install the **new** APK on all phones.

For a **URL that never changes**, deploy Docker to a **cloud server** with your own domain (see `DEPLOY_FOR_UNIVERSAL_APK.md`).

---

## One-page permanent workflow

### Every day / after PC restart

```powershell
cd D:\taxiuser\taxi_customer_app
.\scripts\start-stack.ps1
.\scripts\verify-setup.ps1
```

All items should show `[OK]`.

### When URL changes (after tunnel restart)

```powershell
.\scripts\build-production-apk.ps1
```

Share new `build\app\outputs\flutter-apk\app-release.apk`.

### For users (phones)

1. Install **release APK** only
2. Register → saved in **MongoDB** (Docker)
3. Login on any phone with same email/password
4. If login fails → admin runs `verify-setup.ps1` on PC

---

## What we fixed in the app code

| Fix | Stops |
|-----|--------|
| API URL loaded from assets (not broken dotenv) | Empty URL after hot restart |
| Login checks server **before** you type password | Confusing “wrong password” when server is down |
| Clear error messages | “No host specified” without explanation |
| Release APK uses `--dart-define` URL | Config lost at runtime |

---

## Quick diagnosis

```powershell
.\scripts\verify-setup.ps1
```

| Message | Meaning | Fix |
|---------|---------|-----|
| `[FAIL] Docker` | Backend/MongoDB/OSRM stopped | `.\scripts\start-backend.ps1` |
| `[FAIL] Public tunnel` | cloudflared stopped or URL dead | `.\scripts\start-stack.ps1` |
| `[FAIL] cloudflared` | Tunnel process not running | `.\scripts\expose-docker-public.ps1` |
| `[WARN] No release APK` | Never built | `.\scripts\build-production-apk.ps1` |

---

## Truly permanent (no PC dependency)

For production with many users:

1. Rent a cloud server (AWS, DigitalOcean, …)
2. Run same Docker stack there 24/7
3. Use fixed domain: `https://api.yourdomain.com`
4. Build APK once with that URL — **never changes**

See `DEPLOY_FOR_UNIVERSAL_APK.md`.

---

## Summary

| Temporary (your PC) | Permanent (production) |
|----------------------|------------------------|
| Docker on PC | Docker on cloud VPS |
| trycloudflare.com URL | your-domain.com |
| Rebuild APK if URL changes | Build APK once |
| PC must stay on | Server runs 24/7 |

**The errors repeat when:** Docker stops, tunnel stops, or APK has old URL.  
**They stop when:** `start-stack.ps1` runs after reboot + correct release APK installed.
