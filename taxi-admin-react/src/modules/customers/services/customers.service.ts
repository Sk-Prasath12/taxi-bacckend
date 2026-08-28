import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import type { Customer, CustomerStatus, CustomerTrip } from '../types/customers.types'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'
const ADMIN_CUSTOMERS_ENDPOINT = `${ADMIN_API_BASE_URL}/admin/customers`

function mapDate(value?: string | Date | null): string {
  if (!value) {
    return 'N/A'
  }
  return String(value).slice(0, 10)
}

function toTripStatus(status?: string): CustomerTrip['status'] {
  if (status === 'COMPLETED') {
    return 'Completed'
  }
  if (status === 'CANCELLED') {
    return 'Cancelled'
  }
  return 'Ongoing'
}

function getAuthHeader(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

export async function getCustomers(): Promise<Customer[]> {
  const response = await fetch(`${ADMIN_CUSTOMERS_ENDPOINT}?page=1&limit=100`, {
    headers: getAuthHeader(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch customers.')
  }

  const rows = (payload as { customers?: Array<Record<string, unknown>> } | null)?.customers ?? []
  return rows.map((row) => ({
    id: String(row.id ?? ''),
    name: String(row.name ?? 'Unknown'),
    phone: String(row.phone ?? 'N/A'),
    email: String(row.email ?? 'N/A'),
    joinDate: mapDate((row.createdAt as string | undefined) ?? null),
    status: row.is_blocked ? 'Blocked' : ('Active' satisfies CustomerStatus),
    stats: {
      totalTrips: 0,
      completedTrips: 0,
      cancelledTrips: 0,
      rating: 0,
    },
  }))
}

export async function getCustomerById(customerId: string): Promise<Customer | null> {
  const response = await fetch(`${ADMIN_CUSTOMERS_ENDPOINT}/${customerId}`, {
    headers: getAuthHeader(),
  })
  if (response.status === 404) {
    return null
  }

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch customer details.')
  }

  const data = payload as {
    id?: string
    name?: string
    phone?: string | null
    email?: string
    is_blocked?: boolean
    createdAt?: string
    stats?: {
      total_trips?: number
      completed_trips?: number
      cancelled_trips?: number
      rating?: number
    }
  } | null

  if (!data?.id) {
    return null
  }

  return {
    id: data.id,
    name: data.name ?? 'Unknown',
    phone: data.phone ?? 'N/A',
    email: data.email ?? 'N/A',
    joinDate: mapDate(data.createdAt),
    status: data.is_blocked ? 'Blocked' : ('Active' satisfies CustomerStatus),
    stats: {
      totalTrips: data.stats?.total_trips ?? 0,
      completedTrips: data.stats?.completed_trips ?? 0,
      cancelledTrips: data.stats?.cancelled_trips ?? 0,
      rating: data.stats?.rating ?? 0,
    },
  }
}

export async function getCustomerTrips(customerId: string): Promise<CustomerTrip[]> {
  const response = await fetch(`${ADMIN_CUSTOMERS_ENDPOINT}/${customerId}/rides`, {
    headers: getAuthHeader(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch customer trips.')
  }

  const rides = (payload as { rides?: Array<Record<string, unknown>> } | null)?.rides ?? []
  return rides.map((ride) => ({
    id: String(ride.ride_id ?? 'N/A'),
    driverName: ride.driver_id ? `Driver ${String(ride.driver_id).slice(-6)}` : 'Unassigned',
    pickupLocation: `Lat ${Number((ride.pickup as { lat?: number } | null)?.lat ?? 0).toFixed(4)}, Lng ${Number((ride.pickup as { lng?: number } | null)?.lng ?? 0).toFixed(4)}`,
    dropLocation: `Lat ${Number((ride.drop as { lat?: number } | null)?.lat ?? 0).toFixed(4)}, Lng ${Number((ride.drop as { lng?: number } | null)?.lng ?? 0).toFixed(4)}`,
    fare: Number(ride.fare ?? 0),
    date: mapDate((ride.createdAt as string | undefined) ?? null),
    status: toTripStatus(typeof ride.status === 'string' ? ride.status : undefined),
  }))
}

export async function updateCustomerStatus(
  customerId: string,
  status: CustomerStatus,
  reason?: string,
): Promise<void> {
  const isBlocked = status === 'Blocked'
  if (isBlocked && !reason?.trim()) {
    throw new Error('Block reason is required.')
  }

  const requestBody = isBlocked
    ? { is_blocked: true, reason: reason?.trim() }
    : { is_blocked: false }

  const response = await fetch(`${ADMIN_CUSTOMERS_ENDPOINT}/${customerId}/block`, {
    method: 'PATCH',
    headers: {
      ...getAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  })

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to update customer status.')
  }
}
