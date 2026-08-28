import axios, { AxiosError } from 'axios'
import { ADMIN_AUTH_TOKEN_KEY } from '../modules/auth/services/auth.service'
import { ADMIN_API_BASE_URL } from '../config/api.config'

export type ZoneCoordinate = [number, number]

export interface OperationalZone {
  _id: string
  zone_name: string
  is_active: boolean
  polygon: {
    type: 'Polygon'
    coordinates: ZoneCoordinate[][]
  }
  createdAt?: string
  updatedAt?: string
}

interface ApiResponse<T> {
  success: boolean
  message: string
  data: T
}

const envBaseUrl = ADMIN_API_BASE_URL

function buildApiBaseUrl(baseUrl: string): string {
  const normalized = baseUrl.replace(/\/+$/, '')
  if (normalized.endsWith('/api/v1')) {
    return normalized.replace(/\/api\/v1$/, '/api')
  }
  if (normalized.endsWith('/api')) {
    return normalized
  }
  return `${normalized}/api`
}

const axiosClient = axios.create({
  baseURL: buildApiBaseUrl(envBaseUrl),
  timeout: 15000,
})

axiosClient.interceptors.request.use((config) => {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

function extractErrorMessage(error: unknown, fallbackMessage: string): string {
  if (axios.isAxiosError(error)) {
    const axiosError = error as AxiosError<{ message?: string }>
    return axiosError.response?.data?.message ?? fallbackMessage
  }
  return fallbackMessage
}

export async function createZone(data: {
  zone_name: string
  coordinates: ZoneCoordinate[]
}): Promise<OperationalZone> {
  try {
    const response = await axiosClient.post<ApiResponse<OperationalZone>>(
      '/admin/operational-zones',
      data,
    )
    return response.data.data
  } catch (error) {
    throw new Error(extractErrorMessage(error, 'Unable to create operational zone.'))
  }
}

export async function getZones(): Promise<OperationalZone[]> {
  try {
    const response = await axiosClient.get<ApiResponse<OperationalZone[]>>('/admin/operational-zones')
    return response.data.data
  } catch (error) {
    throw new Error(extractErrorMessage(error, 'Unable to fetch operational zones.'))
  }
}

export async function updateZone(
  id: string,
  data: { zone_name: string; coordinates: ZoneCoordinate[] },
): Promise<OperationalZone> {
  try {
    const response = await axiosClient.put<ApiResponse<OperationalZone>>(
      `/admin/operational-zones/${id}`,
      data,
    )
    return response.data.data
  } catch (error) {
    throw new Error(extractErrorMessage(error, 'Unable to update operational zone.'))
  }
}

export async function toggleZoneStatus(id: string, is_active: boolean): Promise<OperationalZone> {
  try {
    const response = await axiosClient.patch<ApiResponse<OperationalZone>>(
      `/admin/operational-zones/${id}/status`,
      { is_active },
    )
    return response.data.data
  } catch (error) {
    throw new Error(extractErrorMessage(error, 'Unable to update zone status.'))
  }
}
