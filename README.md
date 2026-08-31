# Taxi Platform (Monorepo)

Full taxi stack hosted on **GitLab** group [`taxi_nodejsapp`](https://gitlab.com/groups/taxi_nodejsapp).

**Primary repository:** https://gitlab.com/taxi_nodejsapp/taxi-backend.git (branch `main`)

## Projects in this repo

| Folder | App | Production URL |
|--------|-----|----------------|
| [`taxi-backend-main/`](taxi-backend-main/) | Node.js API | https://taxi-bacckend.vercel.app |
| [`taxi-customer-app/`](taxi-customer-app/) | Flutter customer | APK: https://taxi-apk-downloads.vercel.app |
| [`taxi-driver-app/`](taxi-driver-app/) | Flutter driver | APK: https://taxi-apk-downloads.vercel.app |
| [`taxi-admin-react/`](taxi-admin-react/) | Admin dashboard | https://taxi-admin-react.vercel.app |
| [`apk-downloads/`](apk-downloads/) | APK download site | https://taxi-apk-downloads.vercel.app |

## Clone

```bash
git clone https://gitlab.com/taxi_nodejsapp/taxi-backend.git
cd taxi-backend
```

## Backend

```bash
cd taxi-backend-main
npm install
cp .env.example .env.local
npm run dev
```

## Flutter apps

```bash
cd taxi-customer-app   # or taxi-driver-app
flutter pub get
flutter build apk --release
```

## Admin panel

```bash
cd taxi-admin-react
npm install
npm run dev
```

## Vercel + GitLab (auto deploy)

All Vercel projects connect to the **same GitLab repo**. Set **Root Directory** per project in Vercel → Settings → General:

| Vercel project | Root directory |
|----------------|----------------|
| `taxi-bacckend` | `.` (repo root) |
| `taxi-admin-react` | `taxi-admin-react` |
| `taxi-apk-downloads` | `apk-downloads` |
| `taxi-customer-app` | `taxi-customer-app` |
| `taxi-driver-app` | `taxi-driver-app` |

See [`docs/GITLAB_VERCEL.md`](docs/GITLAB_VERCEL.md) for connect commands.
