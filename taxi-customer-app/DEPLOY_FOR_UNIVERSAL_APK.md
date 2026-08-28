# Deploy backend so the APK works on any device / any network

Your Customer and Driver APKs connect to **one public HTTPS URL**.  
Local Docker (`192.168.x.x:3000`) only works on your home Wi-Fi — not for other phones or mobile data.

---

## Architecture

```text
Any phone (mobile data / any Wi-Fi)
        |
        v
https://api.YOUR-DOMAIN.com   (HTTPS + SSL certificate)
        |
        v
Cloud server (AWS EC2, DigitalOcean, etc.)
  - Node backend :3000
  - MongoDB (private, not public)
  - OSRM routing (optional, same server)
```

---

## Option 1 — VPS (recommended)

### 1. Get a server

- AWS EC2, DigitalOcean Droplet, or similar
- Ubuntu 22.04+, at least 2 GB RAM (OSRM needs memory)
- Open ports: **80**, **443** (and **22** for SSH)

### 2. Install Docker on the server

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

### 3. Copy backend to server

From your PC:

```powershell
scp -r "D:\Taxi Backend new\taxi-backend-main" user@YOUR-SERVER-IP:~/taxi-backend
```

Copy OSRM data if you use routing (`osrm-data` folder).

### 4. Production env on server

On the server, create `~/taxi-backend/.env.local`:

```env
NODE_ENV=production
HOST=0.0.0.0
PORT=3000
PUBLIC_API_URL=https://api.yourdomain.com
CORS_ORIGINS=*

MONGO_URI=mongodb://taxiadmin:STRONG_PASSWORD@mongo:27017/taxi_app?authSource=admin

JWT_ACCESS_SECRET=long-random-secret-min-32-chars
JWT_REFRESH_SECRET=another-long-random-secret

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM_EMAIL=your@gmail.com

OSRM_URL=http://osrm:5000

RAZORPAY_KEY_ID=rzp_test_xxx
RAZORPAY_KEY_SECRET=xxx
```

### 5. Start backend

```bash
cd ~/taxi-backend
docker compose up -d --build
```

### 6. HTTPS with nginx + Let's Encrypt

Point DNS **api.yourdomain.com** → server IP.

Install nginx and certbot, proxy to `localhost:3000`:

```nginx
server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

WebSocket (`Upgrade` headers) is required for live ride updates.

### 7. Verify from anywhere

```bash
curl https://api.yourdomain.com/api/v1/health
```

Must return **200** from your PC and from your phone browser (mobile data).

---

## Option 2 — AWS API Gateway + EC2/ECS

See `D:\Taxi Backend new\taxi-backend-main\docs\API_GATEWAY.md`.

Use one HTTPS domain for REST **and** Socket.IO (ALB with WebSocket support is simplest).

---

## Build universal APK (after backend is live)

### Customer app

```powershell
cd D:\taxiuser\taxi_customer_app
copy .env.production.example .env.production
notepad .env.production
# Set PRODUCTION_API_ORIGIN=https://api.yourdomain.com

.\scripts\build-production-apk.ps1
```

APK: `build\app\outputs\flutter-apk\app-release.apk`

### Driver app

```powershell
cd "D:\Taxi deiver\taxi-app"
.\scripts\build-release-apk.ps1 -ApiUrl "https://api.yourdomain.com"
```

---

## What works automatically in the APK

| Feature | How |
|---------|-----|
| Login on any network | API URL baked into APK at build time |
| Same account on multiple phones | Users stored in MongoDB on server |
| Register new users | POST to public `/api/customers/...` |
| Real-time rides | Socket.IO to same HTTPS domain |
| No manual server setup in app | Users never enter IP or URL |

---

## Still testing on USB (home Wi-Fi only)

```powershell
cd D:\taxiuser\taxi_customer_app
.\scripts\run-on-phone.ps1 -DeviceId YOUR_DEVICE_ID
```

This is **debug only** — not for distributing to other users.

---

## Checklist before sharing APK

- [ ] `https://YOUR-DOMAIN/api/v1/health` returns 200 from mobile data
- [ ] Customer register + login works in browser or Postman
- [ ] Driver app built with same URL
- [ ] Admin can approve drivers (if required)
- [ ] Built with `build-production-apk.ps1` (not debug `flutter run`)
