export interface DashboardStat {
  id:
    | 'totalDrivers'
    | 'driversOnline'
    | 'totalCustomers'
    | 'activeTrips'
    | 'completedTrips'
    | 'tripsToday'
    | 'totalRevenue'
  title: string
  value: number
  valuePrefix?: string
  description: string
}

export interface TripChartPoint {
  day: string
  trips: number
}

export interface RevenueChartPoint {
  month: string
  revenue: number
}

import type { DriverOnlineMode } from '../../drivers/utils/driverOnlineStatus'

export interface DriverActivityItem {
  id: string
  name: string
  phone: string | null
  onlineMode: DriverOnlineMode
  joinedAt: string | null
}

export interface DashboardStatsResponse {
  stats: DashboardStat[]
  tripsSeries: TripChartPoint[]
  revenueSeries: RevenueChartPoint[]
  activeDrivers: DriverActivityItem[]
  driversOnlineCount: number
}
