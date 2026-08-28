/**
 * Single source of truth — same live backend + MongoDB as driver/customer APKs.
 * Driver app: assets/env/app.env → API_BASE_URL=https://taxi-bacckend.vercel.app/api
 * Backend DB: MongoDB Atlas (MONGO_URI on Vercel project taxi-bacckend)
 */
export const ECOSYSTEM = {
  backendOrigin: 'https://taxi-bacckend.vercel.app',
  apiV1: 'https://taxi-bacckend.vercel.app/api/v1',
  apiLegacy: 'https://taxi-bacckend.vercel.app/api',
  socketUrl: 'https://taxi-bacckend.vercel.app',
  database: {
    name: 'taxi_app',
    provider: 'MongoDB Atlas',
    note: 'One cluster for all apps. Configured only on the backend (Vercel env MONGO_URI), not in this React app.',
  },
  admin: {
    email: 'admin@taxigo.com',
    password: 'admin123',
  },
  pages: {
    login: '/admin/login',
    driverApprovals: '/admin/drivers/approvals',
    driversList: '/admin/drivers',
    dashboard: '/admin/dashboard',
  },
  /** End-to-end driver onboarding (same MongoDB via taxi-bacckend.vercel.app) */
  driverFlow: [
    'Driver APK: register email + password → home screen (PENDING)',
    'Driver APK: Profile → Documents → upload all files',
    'Admin: Driver Approvals → Review documents → Approve driver ID',
    'Driver APK: Go Online → accept ride bookings',
  ],
} as const

export const DEFAULT_API_BASE_URL = ECOSYSTEM.apiV1
