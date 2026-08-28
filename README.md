# Taxi Platform (Monorepo)

Full taxi stack: API backend, customer app, driver app, admin dashboard, and APK download site.

## Projects

| Folder | Description | Deploy |
|--------|-------------|--------|
| [`taxi-backend-main/`](taxi-backend-main/) | Node.js REST API + Socket bridge | Vercel: `taxi-bacckend.vercel.app` |
| [`taxi-customer-app/`](taxi-customer-app/) | Flutter customer APK | Vercel APK: `taxi-apk-downloads.vercel.app` |
| [`taxi-driver-app/`](taxi-driver-app/) | Flutter driver APK | Vercel APK: `taxi-apk-downloads.vercel.app` |
| [`taxi-admin-react/`](taxi-admin-react/) | React admin dashboard | Vercel: `taxi-admin-react.vercel.app` |
| [`apk-downloads/`](apk-downloads/) | Static APK download pages | Vercel |

## Backend quick start

```bash
cd taxi-backend-main
npm install
cp .env.example .env.local
npm run dev
```

See `taxi-backend-main/.env.example` for required environment variables.

## Flutter apps

```bash
cd taxi-customer-app   # or taxi-driver-app
flutter pub get
flutter build apk --release
```

## Admin

```bash
cd taxi-admin-react
npm install
npm run dev
```

## GitLab

Primary remote: `https://gitlab.com/taxi_nodejsapp/taxi-backend.git` (branch `main`).
