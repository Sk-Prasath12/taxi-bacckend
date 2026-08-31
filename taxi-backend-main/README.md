# Taxi Backend API

Node.js REST API for customer, driver, and admin apps.

Part of the GitLab group https://gitlab.com/groups/taxi_nodejsapp — monorepo: https://gitlab.com/taxi_nodejsapp/taxi-backend.git

Production: https://taxi-bacckend.vercel.app

## Quick start

```bash
npm install
cp .env.example .env.local
npm run dev
```

See `.env.example` for required environment variables.

## Deploy (Vercel)

From **repository root** (not this folder alone):

```bash
vercel deploy --prod --yes
```

Vercel project `taxi-bacckend` uses root `vercel.json` and builds `taxi-backend-main/`.
