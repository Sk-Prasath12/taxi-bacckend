import type {
  AdminLoginRequest,
  AdminLoginResponse,
} from '../types/auth.types'
import { API_BASE_URL, isProductionMisconfiguredApi } from '../../../config/api.config'

export const ADMIN_AUTH_TOKEN_KEY = 'taxi_admin_auth_token'
const ADMIN_LOGIN_ENDPOINT = `${API_BASE_URL}/auth/login`

type LoginApiPayload = {
  success?: boolean
  message?: string
  data?: {
    accessToken?: string
    token?: string
    user?: {
      email?: string
      role?: string
    }
  }
}

export async function loginAdmin(
  email: AdminLoginRequest['email'],
  password: AdminLoginRequest['password'],
): Promise<AdminLoginResponse> {
  if (!email || !password) {
    throw new Error('Email and password are required.')
  }

  let response: Response
  try {
    response = await fetch(ADMIN_LOGIN_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ email: email.trim().toLowerCase(), password }),
    })
  } catch {
    throw new Error(
      isProductionMisconfiguredApi()
        ? `Cannot reach the API at ${API_BASE_URL}. Set VITE_API_BASE_URL in Vercel to your live backend URL, then redeploy.`
        : `Cannot reach the server at ${API_BASE_URL}. Start the backend or fix VITE_API_BASE_URL.`,
    )
  }

  const payload = (await response.json().catch(() => null)) as LoginApiPayload | null

  if (!response.ok) {
    const errorMessage = payload?.message ?? 'Unable to login. Please try again.'
    if (response.status === 401 && errorMessage.toLowerCase().includes('invalid credentials')) {
      throw new Error(
        `${errorMessage} — Admin account may be missing on the live server. Redeploy taxi-bacckend on Vercel (it auto-creates admin@taxigo.com).`,
      )
    }
    throw new Error(errorMessage)
  }

  const token = payload?.data?.accessToken ?? payload?.data?.token
  const userRole = payload?.data?.user?.role

  if (userRole !== 'ADMIN') {
    throw new Error('Access denied. Use admin credentials only.')
  }

  if (!token) {
    throw new Error('Login succeeded but token was not returned by server.')
  }

  const adminEmail = payload?.data?.user?.email ?? email.trim().toLowerCase()

  return {
    token,
    adminEmail,
  }
}

export function saveAdminSession(token: string): void {
  localStorage.setItem(ADMIN_AUTH_TOKEN_KEY, token)
}

export function clearAdminSession(): void {
  localStorage.removeItem(ADMIN_AUTH_TOKEN_KEY)
}

export function isAdminAuthenticated(): boolean {
  return Boolean(localStorage.getItem(ADMIN_AUTH_TOKEN_KEY))
}
