import type {
  Driver,
  DriverDocument,
  DriverDocumentStatus,
  DriverDocumentType,
  DriverEarningEntry,
  DriverEarningsSummary,
  DriverRideDetails,
  DriverRideItem,
  DriverStatus,
} from '../types/drivers.types'
import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'
import { normalizeDriverOnlineMode } from '../utils/driverOnlineStatus'
const ADMIN_DRIVERS_ENDPOINT = `${ADMIN_API_BASE_URL}/admin/drivers`

const MOCK_DELAY_MS = 250

function getAuthHeader(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

function buildDocuments(seed: number): DriverDocument[] {
  const imageSeed = (offset: number) => `https://images.unsplash.com/photo-${seed + offset}`
  return [
    {
      type: 'driverPhoto',
      title: 'Driver Photo',
      imageUrl: `${imageSeed(0)}?w=600&h=420&fit=crop`,
      status: 'Pending',
    },
    {
      type: 'license',
      title: 'Driving License',
      imageUrl: `${imageSeed(1)}?w=600&h=420&fit=crop`,
      status: 'Pending',
    },
    {
      type: 'vehicleRC',
      title: 'Vehicle RC',
      imageUrl: `${imageSeed(2)}?w=600&h=420&fit=crop`,
      status: 'Pending',
    },
    {
      type: 'insurance',
      title: 'Insurance',
      imageUrl: `${imageSeed(3)}?w=600&h=420&fit=crop`,
      status: 'Pending',
    },
    {
      type: 'vehiclePhoto',
      title: 'Vehicle Photo',
      imageUrl: `${imageSeed(4)}?w=600&h=420&fit=crop`,
      status: 'Pending',
    },
  ]
}

const drivers: Driver[] = [
  {
    id: 'd1',
    name: 'John Doe',
    phone: '+91 98765 40001',
    email: 'john.doe@taxiadmin.com',
    vehicleType: 'Sedan',
    vehicleNumber: 'KA01AB1234',
    vehicleModel: 'Honda City',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.7,
    totalTrips: 420,
    joinDate: '2024-01-18',
    documentsStatus: 'Verified',
    documents: buildDocuments(1684427614330).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 420, completedTrips: 398, cancelledTrips: 22, rating: 4.7 },
  },
  {
    id: 'd2',
    name: 'Michael Ross',
    phone: '+91 98765 40002',
    email: 'michael.ross@taxiadmin.com',
    vehicleType: 'SUV',
    vehicleNumber: 'KA02CD5678',
    vehicleModel: 'Hyundai Creta',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.8,
    totalTrips: 510,
    joinDate: '2023-11-12',
    documentsStatus: 'Verified',
    documents: buildDocuments(1684166132925).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 510, completedTrips: 489, cancelledTrips: 21, rating: 4.8 },
  },
  {
    id: 'd3',
    name: 'David Singh',
    phone: '+91 98765 40003',
    email: 'david.singh@taxiadmin.com',
    vehicleType: 'Hatchback',
    vehicleNumber: 'KA03EF9101',
    vehicleModel: 'Maruti Baleno',
    status: 'Inactive',
    onlineMode: 'OFFLINE',
    rating: 4.3,
    totalTrips: 305,
    joinDate: '2023-08-30',
    documentsStatus: 'Verified',
    documents: buildDocuments(1687187173632).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 305, completedTrips: 290, cancelledTrips: 15, rating: 4.3 },
  },
  {
    id: 'd4',
    name: 'Aarav Patel',
    phone: '+91 98765 40004',
    email: 'aarav.patel@taxiadmin.com',
    vehicleType: 'Sedan',
    vehicleNumber: 'KA04GH1122',
    vehicleModel: 'Toyota Etios',
    status: 'Pending',
    onlineMode: 'OFFLINE',
    rating: 0,
    totalTrips: 0,
    joinDate: '2026-02-10',
    documentsStatus: 'Pending',
    documents: buildDocuments(1680251303764),
    stats: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, rating: 0 },
  },
  {
    id: 'd5',
    name: 'Nikhil Verma',
    phone: '+91 98765 40005',
    email: 'nikhil.verma@taxiadmin.com',
    vehicleType: 'SUV',
    vehicleNumber: 'KA05IJ3344',
    vehicleModel: 'Mahindra XUV300',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.6,
    totalTrips: 388,
    joinDate: '2024-03-02',
    documentsStatus: 'Verified',
    documents: buildDocuments(1685192392090).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 388, completedTrips: 372, cancelledTrips: 16, rating: 4.6 },
  },
  {
    id: 'd6',
    name: 'Rohan Mehta',
    phone: '+91 98765 40006',
    email: 'rohan.mehta@taxiadmin.com',
    vehicleType: 'Sedan',
    vehicleNumber: 'KA06KL5566',
    vehicleModel: 'Skoda Slavia',
    status: 'Inactive',
    onlineMode: 'OFFLINE',
    rating: 4.1,
    totalTrips: 210,
    joinDate: '2022-12-15',
    documentsStatus: 'Verified',
    documents: buildDocuments(1687164722726).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 210, completedTrips: 197, cancelledTrips: 13, rating: 4.1 },
  },
  {
    id: 'd7',
    name: 'Vikram Rao',
    phone: '+91 98765 40007',
    email: 'vikram.rao@taxiadmin.com',
    vehicleType: 'Hatchback',
    vehicleNumber: 'KA07MN7788',
    vehicleModel: 'Hyundai i20',
    status: 'Pending',
    onlineMode: 'OFFLINE',
    rating: 0,
    totalTrips: 0,
    joinDate: '2026-01-21',
    documentsStatus: 'Pending',
    documents: buildDocuments(1682562121021),
    stats: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, rating: 0 },
  },
  {
    id: 'd8',
    name: 'Karan Malik',
    phone: '+91 98765 40008',
    email: 'karan.malik@taxiadmin.com',
    vehicleType: 'SUV',
    vehicleNumber: 'KA08OP9900',
    vehicleModel: 'Kia Seltos',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.5,
    totalTrips: 330,
    joinDate: '2024-04-08',
    documentsStatus: 'Verified',
    documents: buildDocuments(1689154494602).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 330, completedTrips: 315, cancelledTrips: 15, rating: 4.5 },
  },
  {
    id: 'd9',
    name: 'Shreyas Iyer',
    phone: '+91 98765 40009',
    email: 'shreyas.iyer@taxiadmin.com',
    vehicleType: 'Sedan',
    vehicleNumber: 'KA09QR2211',
    vehicleModel: 'Maruti Ciaz',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.4,
    totalTrips: 275,
    joinDate: '2023-10-10',
    documentsStatus: 'Verified',
    documents: buildDocuments(1684698383420).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 275, completedTrips: 260, cancelledTrips: 15, rating: 4.4 },
  },
  {
    id: 'd10',
    name: 'Ritesh Kumar',
    phone: '+91 98765 40010',
    email: 'ritesh.kumar@taxiadmin.com',
    vehicleType: 'Hatchback',
    vehicleNumber: 'KA10ST4433',
    vehicleModel: 'Tata Altroz',
    status: 'Inactive',
    onlineMode: 'OFFLINE',
    rating: 4.0,
    totalTrips: 190,
    joinDate: '2023-06-18',
    documentsStatus: 'Verified',
    documents: buildDocuments(1689517045762).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 190, completedTrips: 180, cancelledTrips: 10, rating: 4.0 },
  },
  {
    id: 'd11',
    name: 'Faizan Ali',
    phone: '+91 98765 40011',
    email: 'faizan.ali@taxiadmin.com',
    vehicleType: 'SUV',
    vehicleNumber: 'KA11UV6655',
    vehicleModel: 'MG Hector',
    status: 'Active',
    onlineMode: 'OFFLINE',
    rating: 4.9,
    totalTrips: 620,
    joinDate: '2022-09-07',
    documentsStatus: 'Verified',
    documents: buildDocuments(1682089232525).map((doc) => ({ ...doc, status: 'Approved' })),
    stats: { totalTrips: 620, completedTrips: 601, cancelledTrips: 19, rating: 4.9 },
  },
  {
    id: 'd12',
    name: 'Sahil Jain',
    phone: '+91 98765 40012',
    email: 'sahil.jain@taxiadmin.com',
    vehicleType: 'Sedan',
    vehicleNumber: 'KA12WX8877',
    vehicleModel: 'Volkswagen Virtus',
    status: 'Pending',
    onlineMode: 'OFFLINE',
    rating: 0,
    totalTrips: 0,
    joinDate: '2026-02-24',
    documentsStatus: 'Pending',
    documents: buildDocuments(1681489486201),
    stats: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, rating: 0 },
  },
]

const earningsByDriver: Record<string, DriverEarningEntry[]> = {
  d1: [
    { id: 'e1', date: '2026-03-12', tripId: 'TRP-2201', fare: 540, driverEarnings: 410 },
    { id: 'e2', date: '2026-03-11', tripId: 'TRP-2194', fare: 430, driverEarnings: 325 },
    { id: 'e3', date: '2026-03-10', tripId: 'TRP-2181', fare: 620, driverEarnings: 470 },
    { id: 'e4', date: '2026-03-09', tripId: 'TRP-2169', fare: 380, driverEarnings: 290 },
    { id: 'e5', date: '2026-03-08', tripId: 'TRP-2162', fare: 790, driverEarnings: 600 },
  ],
}

function wait<T>(value: T): Promise<T> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(value), MOCK_DELAY_MS)
  })
}

export async function getDrivers(): Promise<Driver[]> {
  const response = await fetch(`${ADMIN_DRIVERS_ENDPOINT}?page=1&limit=100`, {
    headers: getAuthHeader(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch drivers.')
  }

  const rows = (payload as { drivers?: Array<Record<string, unknown>> } | null)?.drivers ?? []
  return rows.map((row) => ({
    id: String(row.id ?? ''),
    name: String(row.name ?? 'Unknown'),
    phone: String(row.phone ?? 'N/A'),
    email: String(row.email ?? 'N/A'),
    vehicleType: String(row.vehicle_type ?? 'N/A'),
    vehicleNumber: String(row.vehicle_number ?? 'N/A'),
    vehicleModel: String(row.vehicle_model ?? 'N/A'),
    status: row.is_blocked ? 'Blocked' : ('Active' satisfies DriverStatus),
    onlineMode: normalizeDriverOnlineMode(String(row.driver_status ?? 'OFFLINE')),
    rating: Number(row.overall_rating ?? 0),
    totalTrips: Number(row.total_trips ?? 0),
    joinDate: String(row.createdAt ?? '').slice(0, 10) || 'N/A',
    documentsStatus:
      row.is_driver_verified === true && String(row.driver_verification_status ?? '') === 'APPROVED'
        ? 'Verified'
        : 'Pending',
    documents: [],
    stats: {
      totalTrips: Number(row.total_trips ?? 0),
      completedTrips: 0,
      cancelledTrips: 0,
      rating: Number(row.overall_rating ?? 0),
    },
  }))
}

export async function getDriverById(driverId: string): Promise<Driver | null> {
  const response = await fetch(`${ADMIN_DRIVERS_ENDPOINT}/${driverId}`, {
    headers: getAuthHeader(),
  })
  if (response.status === 404) {
    return null
  }

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch driver details.')
  }

  const data = payload as {
    id?: string
    name?: string
    phone?: string | null
    email?: string
    is_blocked?: boolean
    createdAt?: string
    driver_profile?: {
      vehicle_type_name?: string
      vehicle_reg_number?: string
      vehicle_model?: string
    } | null
    vehicle_type?: string | null
    vehicle_number?: string | null
    vehicle_model?: string | null
    overall_rating?: number
    stats?: {
      total_trips?: number
      completed_trips?: number
      cancelled_trips?: number
      rating?: number
    }
    is_driver_verified?: boolean
    driver_verification_status?: string
    driver_status?: string
  } | null

  if (!data?.id) {
    return null
  }

  return {
    id: data.id,
    name: data.name ?? 'Unknown',
    phone: data.phone ?? 'N/A',
    email: data.email ?? 'N/A',
    vehicleType: data.vehicle_type ?? data.driver_profile?.vehicle_type_name ?? 'N/A',
    vehicleNumber: data.vehicle_number ?? data.driver_profile?.vehicle_reg_number ?? 'N/A',
    vehicleModel: data.vehicle_model ?? data.driver_profile?.vehicle_model ?? 'N/A',
    status: data.is_blocked ? 'Blocked' : ('Active' satisfies DriverStatus),
    onlineMode: normalizeDriverOnlineMode(data.driver_status),
    rating: Number(data.overall_rating ?? data.stats?.rating ?? 0),
    totalTrips: data.stats?.total_trips ?? 0,
    joinDate: String(data.createdAt ?? '').slice(0, 10) || 'N/A',
    documentsStatus:
      data.is_driver_verified === true && data.driver_verification_status === 'APPROVED'
        ? 'Verified'
        : 'Pending',
    documents: [],
    stats: {
      totalTrips: data.stats?.total_trips ?? 0,
      completedTrips: data.stats?.completed_trips ?? 0,
      cancelledTrips: data.stats?.cancelled_trips ?? 0,
      rating: Number(data.stats?.rating ?? data.overall_rating ?? 0),
    },
  }
}

export async function getPendingDrivers(): Promise<Driver[]> {
  return wait(drivers.filter((driver) => driver.status === 'Pending'))
}

export async function getPendingDriverApprovals(): Promise<Driver[]> {
  return getPendingDrivers()
}

export async function updateDriverApproval(
  driverId: string,
  status: Extract<DriverStatus, 'Active' | 'Inactive' | 'Blocked'>,
): Promise<void> {
  const driver = drivers.find((item) => item.id === driverId)
  if (driver) {
    driver.status = status
    driver.documentsStatus = 'Verified'
  }
  return wait(undefined)
}

export async function updateDriverStatus(
  driverId: string,
  status: Extract<DriverStatus, 'Active' | 'Blocked'>,
): Promise<void> {
  const requestBody =
    status === 'Blocked'
      ? { is_blocked: true, reason: 'Blocked by admin from admin panel' }
      : { is_blocked: false }

  const response = await fetch(`${ADMIN_DRIVERS_ENDPOINT}/${driverId}/block`, {
    method: 'PATCH',
    headers: {
      ...getAuthHeader(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(requestBody),
  })

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to update driver status.')
  }
}

export async function getDriverDocuments(driverId: string): Promise<DriverDocument[]> {
  const driver = drivers.find((item) => item.id === driverId)
  return wait(driver?.documents ?? [])
}

export async function updateDriverDocumentStatus(
  driverId: string,
  documentType: DriverDocumentType,
  status: DriverDocumentStatus,
  rejectionReason?: string,
): Promise<void> {
  const driver = drivers.find((item) => item.id === driverId)
  const doc = driver?.documents.find((item) => item.type === documentType)

  if (driver && doc) {
    doc.status = status
    doc.rejectionReason = status === 'Rejected' ? rejectionReason ?? 'Document rejected' : undefined
    driver.documentsStatus = driver.documents.every((item) => item.status === 'Approved')
      ? 'Verified'
      : 'Pending'
  }

  return wait(undefined)
}

export async function approveDriverAfterDocumentReview(driverId: string): Promise<void> {
  const driver = drivers.find((item) => item.id === driverId)
  if (!driver) {
    return wait(undefined)
  }

  const canApprove = driver.documents.every((doc) => doc.status === 'Approved')
  if (!canApprove) {
    throw new Error('All documents must be approved before driver approval.')
  }

  driver.status = 'Active'
  driver.documentsStatus = 'Verified'
  driver.driverRejectionReason = undefined
  return wait(undefined)
}

export async function rejectDriverAfterDocumentReview(
  driverId: string,
  reason: string,
): Promise<void> {
  const driver = drivers.find((item) => item.id === driverId)
  if (driver) {
    driver.status = 'Inactive'
    driver.driverRejectionReason = reason
    driver.documentsStatus = 'Pending'
  }

  return wait(undefined)
}

export async function getDriverEarnings(driverId: string): Promise<DriverEarningEntry[]> {
  return wait(earningsByDriver[driverId] ?? [])
}

export async function getDriverEarningsSummary(driverId: string): Promise<DriverEarningsSummary> {
  const entries = earningsByDriver[driverId] ?? []
  const totalEarnings = entries.reduce((sum, item) => sum + item.driverEarnings, 0)
  const today = new Date().toISOString().slice(0, 10)
  const todayEarnings = entries
    .filter((item) => item.date === today)
    .reduce((sum, item) => sum + item.driverEarnings, 0)

  return wait({
    totalEarnings,
    todayEarnings,
    tripsCompleted: entries.length,
  })
}

export async function getDriverRides(driverId: string): Promise<DriverRideItem[]> {
  const response = await fetch(`${ADMIN_DRIVERS_ENDPOINT}/${driverId}/rides`, {
    headers: getAuthHeader(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch driver rides.')
  }

  return ((payload as { rides?: DriverRideItem[] } | null)?.rides ?? []).map((ride) => ({
    ...ride,
    duration_min: ride.duration_min ?? null,
  }))
}

export async function getDriverRideDetails(
  driverId: string,
  rideId: string,
): Promise<DriverRideDetails | null> {
  const response = await fetch(`${ADMIN_DRIVERS_ENDPOINT}/${driverId}/rides/${rideId}`, {
    headers: getAuthHeader(),
  })
  if (response.status === 404) {
    return null
  }

  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    throw new Error((payload as { message?: string } | null)?.message ?? 'Unable to fetch ride details.')
  }

  return (payload as DriverRideDetails | null) ?? null
}
