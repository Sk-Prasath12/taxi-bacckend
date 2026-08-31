# GitLab + Vercel deployment

## GitLab group

- Group: https://gitlab.com/groups/taxi_nodejsapp
- Monorepo: https://gitlab.com/taxi_nodejsapp/taxi-backend.git
- Branch: `main`

## Git remote (local)

```bash
git remote -v
# origin → https://gitlab.com/taxi_nodejsapp/taxi-backend.git
```

Push updates:

```bash
git add .
git commit -m "your message"
git push origin main
```

## Vercel projects (production)

| Project | URL | Root directory |
|---------|-----|----------------|
| taxi-bacckend | https://taxi-bacckend.vercel.app | `.` |
| taxi-admin-react | https://taxi-admin-react.vercel.app | `taxi-admin-react` |
| taxi-apk-downloads | https://taxi-apk-downloads.vercel.app | `apk-downloads` |
| taxi-customer-app | https://taxi-customer-app.vercel.app | `taxi-customer-app` |
| taxi-driver-app | https://taxi-driver-app-fawn.vercel.app | `taxi-driver-app` |

## Connect GitLab to Vercel (one-time per project)

1. In [Vercel Dashboard](https://vercel.com) → **Settings → Git** → connect **GitLab** account (OAuth).
2. For each project above: **Settings → Git** → connect repository `taxi_nodejsapp/taxi-backend`.
3. Set **Root Directory** (table above) and **Production Branch** = `main`.
4. Enable **Auto Deploy** on push to `main`.

CLI (from repo root, with Vercel CLI logged in):

```bash
vercel git connect https://gitlab.com/taxi_nodejsapp/taxi-backend.git
```

Run from each linked project folder (`taxi-admin-react`, `apk-downloads`, etc.) after `vercel link`.

## Manual deploy (without Git hook)

```bash
# Backend API
vercel deploy --prod --yes

# Admin
cd taxi-admin-react && vercel deploy --prod --yes

# APK site
cd apk-downloads && vercel deploy --prod --yes
```
