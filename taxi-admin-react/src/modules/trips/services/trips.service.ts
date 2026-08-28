import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import type { TripDetails, TripListItem, TripStatus } from '../types/trips.types'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'

type ApiRideRow = {
  ride_id?: string
  status?: string
  client_status?: string
  pickup?: { address?: string; lat?: number; lng?: number }
  drop?: { address?: string; lat?: number; lng?: number }
  fare?: number
  distance_km?: number
  duration_min?: number | null
  actual_distance_km?: number | null
  actual_duration_min?: number | null
  payment_mode?: string
  payment_status?: string
  finance_processed?: boolean
  emergency_alerted?: boolean
  vehicle_type?: string | null
  customer?: { name?: string; phone?: string | null; email?: string | null } | null
  driver?: { name?: string; phone?: string | null; email?: string | null } | null
  created_at?: string | null
  updated_at?: string | null
  createdAt?: string | null
  updatedAt?: string | null
  completed_at?: string | null
}

function authHeaders(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

function mapStatus(raw?: string): TripStatus {
  const s = (raw ?? '').toUpperCase()
  if (s === 'COMPLETED') return 'Completed'
  if (s === 'CANCELLED') return 'Cancelled'
  return 'Active'
}

function formatDate(value?: string | null): string {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return value
  return d.toISOString().slice(0, 10)
}

function rideDate(row: ApiRideRow): string {
  return formatDate(
    row.completed_at ??
      row.created_at ??
      row.createdAt ??
      row.updated_at ??
      row.updatedAt,
  )
}

function mapRideToListItem(row: ApiRideRow): TripListItem {
  const emergency = row.emergency_alerted === true
  return {
    tripId: row.ride_id ?? '—',
    customerName: row.customer?.name ?? 'Customer',
    driverName: row.driver?.name ?? 'Unassigned',
    pickupLocation: row.pickup?.address ?? 'Pickup',
    dropLocation: row.drop?.address ?? 'Drop',
    fare: Number(row.fare ?? 0),
    status: mapStatus(row.status),
    date: rideDate(row),
    paymentMode: row.payment_mode ?? undefined,
    paymentStatus: row.payment_status ?? undefined,
    emergency: emergency || undefined,
  }
}

async function fetchRidesFromApi(status: 'all' | 'active' | 'completed' | 'cancelled'): Promise<ApiRideRow[]> {
  const urls =
    status === 'active'
      ? [`${ADMIN_API_BASE_URL}/admin/rides/live`, `${ADMIN_API_BASE_URL}/v1/admin/rides/live`]
      : [
          `${ADMIN_API_BASE_URL}/admin/rides/history?status=${status}`,
          `${ADMIN_API_BASE_URL}/v1/admin/rides/history?status=${status}`,
        ]

  let lastError = 'Unable to load rides.'
  for (const url of urls) {
    try {
      const response = await fetch(url, { headers: authHeaders() })
      const payload = await response.json().catch(() => null)
      if (!response.ok) {
        lastError = (payload as { message?: string } | null)?.message ?? lastError
        continue
      }
      const data = (payload as { data?: { rides?: ApiRideRow[] } } | null)?.data
      if (Array.isArray(data?.rides)) {
        return data.rides
      }
    } catch (error) {
      lastError = error instanceof Error ? error.message : lastError
    }
  }
  throw new Error(lastError)
}

export async function getTrips(): Promise<TripListItem[]> {
  const [active, completed, cancelled] = await Promise.all([
    fetchRidesFromApi('active').catch(() => [] as ApiRideRow[]),
    fetchRidesFromApi('completed').catch(() => [] as ApiRideRow[]),
    fetchRidesFromApi('cancelled').catch(() => [] as ApiRideRow[]),
  ])
  const merged = [...active, ...completed, ...cancelled]
  const seen = new Set<string>()
  const unique: TripListItem[] = []
  for (const row of merged) {
    const item = mapRideToListItem(row)
    if (seen.has(item.tripId)) continue
    seen.add(item.tripId)
    unique.push(item)
  }
  return unique.sort((a, b) => b.date.localeCompare(a.date))
}

export async function getTripById(tripId: string): Promise<TripDetails | null> {
  const urls = [
    `${ADMIN_API_BASE_URL}/admin/rides/${tripId}`,
    `${ADMIN_API_BASE_URL}/v1/admin/rides/${tripId}`,
    `${ADMIN_API_BASE_URL}/admin/rides/live/${tripId}`,
    `${ADMIN_API_BASE_URL}/v1/admin/rides/live/${tripId}`,
  ]

  for (const url of urls) {
    try {
      const response = await fetch(url, { headers: authHeaders() })
      const payload = await response.json().catch(() => null)
      if (!response.ok) continue
      const ride = (payload as { data?: { ride?: Record<string, unknown> } } | null)?.data?.ride
      if (!ride || typeof ride !== 'object') continue

      const pickup = ride.pickup as { address?: string } | undefined
      const drop = ride.drop as { address?: string } | undefined
      const actualDrop = ride.actual_drop as { address?: string } | undefined
      const driver = ride.driver as { name?: string; phone?: string; vehicle?: { type?: string } } | undefined
      const customer = ride.customer as { name?: string; phone?: string } | undefined
      const statusRaw = String(ride.status ?? '')
      const distanceKm = Number(ride.actual_distance_km ?? ride.distance_km ?? 0)
      const durationMin = Number(ride.actual_duration_min ?? ride.duration_min ?? 0)
      const fare = Number(ride.fare ?? 0)
      const paymentMode = String(ride.payment_mode ?? 'CASH')
      const paymentStatus = String(ride.payment_status ?? 'PENDING')

      return {
        tripId: String(ride.ride_id ?? ride.id ?? tripId),
        status: mapStatus(statusRaw),
        date: formatDate(
          String(
            ride.completed_at ??
              ride.created_at ??
              ride.createdAt ??
              ride.updated_at ??
              ride.updatedAt ??
              '',
          ),
        ),
        fare,
        paymentMode,
        paymentStatus,
        financeProcessed: Boolean(ride.finance_processed),
        emergencyAlerted: Boolean(ride.emergency_alerted),
        driver: {
          name: driver?.name ?? 'Driver',
          phone: driver?.phone ?? '—',
          rating: 4.5,
          vehicleType: driver?.vehicle?.type ?? String(ride.vehicle_type ?? '—'),
        },
        customer: {
          name: customer?.name ?? 'Customer',
          phone: customer?.phone ?? '—',
          rating: 4.5,
        },
        route: {
          pickupLocation: pickup?.address ?? 'Pickup',
          dropLocation: actualDrop?.address ?? drop?.address ?? 'Drop',
          distanceKm,
          durationMinutes: durationMin,
        },
        fareBreakdown: {
          baseFare: fare,
          distanceFare: 0,
          timeFare: 0,
          taxes: 0,
          discount: 0,
          totalFare: fare,
        },
        timeline: [
          { label: 'Trip Requested', completed: true },
          { label: 'Driver Accepted', completed: Boolean(ride.driver_id) },
          {
            label: 'Trip Started',
            completed: ['STARTED', 'PICKED_UP', 'IN_TRANSIT', 'COMPLETED'].includes(statusRaw),
          },
          {
            label: 'Drop Reached',
            completed: Boolean(ride.drop_reached) || statusRaw === 'COMPLETED',
          },
          { label: 'Payment', completed: paymentStatus === 'SUCCESS' },
          { label: 'Trip Completed', completed: statusRaw === 'COMPLETED' },
        ],
      }
    } catch {
      // try next url
    }
  }
  return null
}
