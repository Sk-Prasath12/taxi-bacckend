# Share Taxi APKs on Vercel

One page with download links for **Driver** and **Customer** APKs.

## 1. Build APKs (point at your live backend)

```powershell
# Backend must return JSON from /api/v1/health first
$api = "https://taxi-bacckend.vercel.app"

cd "D:\Taxi deiver\taxi-app"
.\scripts\build-release-apk.ps1 -ApiUrl $api

cd "D:\taxiuser\taxi_customer_app"
.\scripts\build-production-apk.ps1 -ApiUrl $api
```

## 2. Copy APKs and deploy this site

```powershell
cd "D:\Taxi Backend new\apk-downloads"
.\deploy.ps1
```

After deploy, Vercel prints a URL like:

```text
https://taxi-apk-downloads.vercel.app
```

Share that link. Testers open it on Android and tap:

- **Download Driver APK** → `/downloads/taxi-driver.apk`
- **Download Customer APK** → `/downloads/taxi-customer.apk`

## 3. Backend must work first

Phones cannot use `localhost`. On Vercel set:

- Root Directory: `taxi-backend-main`
- `MONGO_URI` = MongoDB Atlas (not `127.0.0.1`)
- All JWT / SMTP / Razorpay vars from `.env.local`
- **Deployment Protection → OFF** for Production

Verify:

```text
https://taxi-bacckend.vercel.app/api/v1/health
→ {"success":true,"message":"Service healthy"}
```
