declare global {
  interface Window {
    __TAXI_ADMIN_CONFIG__?: {
      apiBaseUrl?: string
    }
  }
}

import { DEFAULT_API_BASE_URL, ECOSYSTEM } from './ecosystem.config'

export { ECOSYSTEM }

function trimTrailingSlash(url: string): string {
  return url.replace(/\/+$/, '')
}

function readRuntimeApiBaseUrl(): string | null {
  if (typeof window === 'undefined') {
    return null
  }
  const fromWindow = window.__TAXI_ADMIN_CONFIG__?.apiBaseUrl?.trim()
  if (fromWindow) {
    return trimTrailingSlash(fromWindow)
  }
  return null
}

function readBuildApiBaseUrl(): string | null {
  const fromEnv = import.meta.env.VITE_API_BASE_URL?.trim()
  if (fromEnv) {
    return trimTrailingSlash(fromEnv)
  }
  return null
}

/** Primary admin API base (v1). Override via VITE_API_BASE_URL, public/config.js, or ecosystem.config.ts */
export const API_BASE_URL = readRuntimeApiBaseUrl() ?? readBuildApiBaseUrl() ?? DEFAULT_API_BASE_URL

/** Legacy /api prefix used by some mobile routes */
export const ADMIN_API_BASE_URL = API_BASE_URL.replace(/\/api\/v1$/i, '/api')

export function isProductionMisconfiguredApi(): boolean {
  if (!import.meta.env.PROD) {
    return false
  }
  return /localhost|127\.0\.0\.1|192\.168\./i.test(API_BASE_URL)
}

export function getApiConfigHint(): string {
  if (isProductionMisconfiguredApi()) {
    return `Admin is calling ${API_BASE_URL}. Set VITE_API_BASE_URL in Vercel to your live backend (same URL as the driver APK), then redeploy.`
  }
  return `Connected API: ${API_BASE_URL}`
}
