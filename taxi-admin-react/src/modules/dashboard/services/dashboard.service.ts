import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import { normalizeDriverOnlineMode } from '../../drivers/utils/driverOnlineStatus'
import type { DashboardStatsResponse, DriverActivityItem } from '../types/dashboard.types'
import { API_BASE_URL } from '../../../config/api.config'
const DASHBOARD_METRICS_ENDPOINT = `${API_BASE_URL}/admin/dashboard/metrics`
const ACTIVE_DRIVERS_ENDPOINT = `${API_BASE_URL}/admin/drivers/active`

type DashboardMetricsApi = {
  total_drivers?: number
  total_customers?: number
  active_trips?: number
  completed_trips?: number
  trips_today?: number
  total_revenue?: number
  trips_per_day?: Array<{ date?: string; trips?: number }>
  revenue_growth?: {
    per_day?: Array<{ date?: string; revenue?: number }>
  }
}

type ActiveDriversApi = {
  data?: {
    total?: number
    drivers?: Array<{
      id?: string
      name?: string
      email?: string
      phone?: string | null
      status?: string
      joined_at?: string | null
    }>
  }
}

function getAuthHeader(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

function toShortWeekday(value?: string): string {
  if (!value) {
    return 'N/A'
  }
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) {
    return 'N/A'
  }
  return date.toLocaleDateString('en-US', { weekday: 'short' })
}

function mapMetricsToDashboardData(metrics: DashboardMetricsApi): DashboardStatsResponse {
  return {
    stats: [
      {
        id: 'totalDrivers',
        title: 'Total Drivers',
        value: Number(metrics.total_drivers ?? 0),
        description: 'Registered drivers in the platform',
      },
      {
        id: 'totalCustomers',
        title: 'Total Customers',
        value: Number(metrics.total_customers ?? 0),
        description: 'Customers with completed sign-up',
      },
      {
        id: 'activeTrips',
        title: 'Active Trips',
        value: Number(metrics.active_trips ?? 0),
        description: 'Trips currently in progress',
      },
      {
        id: 'completedTrips',
        title: 'Completed Trips',
        value: Number(metrics.completed_trips ?? 0),
        description: 'Trips completed successfully',
      },
      {
        id: 'tripsToday',
        title: 'Trips Today',
        value: Number(metrics.trips_today ?? 0),
        description: 'Total rides created today',
      },
      {
        id: 'totalRevenue',
        title: 'Total Revenue',
        value: Number(metrics.total_revenue ?? 0),
        valuePrefix: '₹',
        description: 'Gross earnings till date',
      },
    ],
    tripsSeries: (metrics.trips_per_day ?? []).map((item) => ({
      day: toShortWeekday(item.date),
      trips: Number(item.trips ?? 0),
    })),
    revenueSeries: (metrics.revenue_growth?.per_day ?? []).map((item) => ({
      month: toShortWeekday(item.date),
      revenue: Number(item.revenue ?? 0),
    })),
    activeDrivers: [],
    driversOnlineCount: 0,
  }
}

function mapDrivers(payload: ActiveDriversApi | null): {
  drivers: DriverActivityItem[]
  total: number
} {
  const rows = payload?.data?.drivers ?? []
  const total =
    typeof payload?.data?.total === 'number' ? payload.data.total : rows.length
  const drivers = rows.map((driver) => ({
    id: String(driver.id ?? ''),
    name: String(driver.name ?? 'Unknown'),
    phone: driver.phone != null ? String(driver.phone) : null,
    onlineMode: normalizeDriverOnlineMode(driver.status),
    joinedAt: driver.joined_at != null ? String(driver.joined_at) : null,
  }))
  return { drivers, total }
}

export async function fetchOnlineDrivers(): Promise<{
  drivers: DriverActivityItem[]
  total: number
}> {
  const headers = getAuthHeader()
  const response = await fetch(ACTIVE_DRIVERS_ENDPOINT, { headers })
  if (!response.ok) {
    return { drivers: [], total: 0 }
  }
  const payload = (await response.json().catch(() => null)) as ActiveDriversApi | null
  return mapDrivers(payload)
}

export async function getDashboardStats(): Promise<DashboardStatsResponse> {
  const headers = getAuthHeader()

  const [metricsResponse, activeDriversResponse] = await Promise.all([
    fetch(DASHBOARD_METRICS_ENDPOINT, { headers }),
    fetch(ACTIVE_DRIVERS_ENDPOINT, { headers }),
  ])

  const metricsPayload = await metricsResponse.json().catch(() => null)
  if (!metricsResponse.ok) {
    throw new Error((metricsPayload as { message?: string } | null)?.message ?? 'Unable to fetch dashboard metrics.')
  }

  const dashboardData = mapMetricsToDashboardData((metricsPayload as DashboardMetricsApi | null) ?? {})

  if (activeDriversResponse.ok) {
    const activeDriversPayload = await activeDriversResponse.json().catch(() => null)
    const online = mapDrivers(activeDriversPayload as ActiveDriversApi | null)
    dashboardData.activeDrivers = online.drivers
    dashboardData.driversOnlineCount = online.total
  } else {
    dashboardData.activeDrivers = []
    dashboardData.driversOnlineCount = 0
  }

  dashboardData.stats.splice(1, 0, {
    id: 'driversOnline',
    title: 'Drivers Online',
    value: dashboardData.driversOnlineCount,
    description: 'Drivers currently ONLINE or on an active ride',
  })

  return dashboardData
}
