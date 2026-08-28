export type DriverStatus = 'Active' | 'Inactive' | 'Pending' | 'Blocked'
export type DriverOnlineMode = 'ONLINE' | 'BUSY' | 'OFFLINE'
export type DriverDocumentStatus = 'Pending' | 'Approved' | 'Rejected'
export type DriverDocumentType =
  | 'driverPhoto'
  | 'license'
  | 'vehicleRC'
  | 'insurance'
  | 'vehiclePhoto'

export interface DriverDocument {
  type: DriverDocumentType
  title: string
  imageUrl: string
  status: DriverDocumentStatus
  rejectionReason?: string
}

/** Backend driver verification queue (GET /admin/drivers/verification) */
export interface DriverVerificationQueueItem {
  id: string
  name: string
  email: string
  phone: string | null
  driver_verification_status: string
  documents_uploaded_count: number
  joined_at: string | null
}

/** GET /admin/drivers/verified — KYC-approved drivers */
export interface VerifiedDriverListItem {
  id: string
  name: string
  email: string
  phone: string | null
  driver_status: string
  is_driver_verified: boolean
  driver_verification_status: string
  joined_at: string | null
}

/** Backend admin document row (GET /admin/drivers/:id/documents) */
export type AdminApiDocumentType = 'IDENTITY' | 'VEHICLE' | 'BANK' | 'PERSONAL'
export type AdminApiDocumentStatus = 'PENDING' | 'APPROVED' | 'REJECTED'

export interface AdminDriverDocumentRow {
  id: string
  user_id: string
  document_type: AdminApiDocumentType
  document_slot: string | null
  file_url: string
  file_key: string
  status: AdminApiDocumentStatus
  rejection_reason: string | null
}

export interface DriverStats {
  totalTrips: number
  completedTrips: number
  cancelledTrips: number
  rating: number
}

export interface Driver {
  id: string
  name: string
  phone: string
  email: string
  vehicleType: string
  vehicleNumber: string
  vehicleModel: string
  status: DriverStatus
  onlineMode: DriverOnlineMode
  rating: number
  totalTrips: number
  joinDate: string
  documentsStatus: 'Verified' | 'Pending'
  driverRejectionReason?: string
  documents: DriverDocument[]
  stats: DriverStats
}

export interface DriverEarningEntry {
  id: string
  date: string
  tripId: string
  fare: number
  driverEarnings: number
}

export interface DriverEarningsSummary {
  totalEarnings: number
  todayEarnings: number
  tripsCompleted: number
}

export type RideLifecycleStatus =
  | 'PENDING_CONFIRMATION'
  | 'SEARCHING_DRIVER'
  | 'DRIVER_ASSIGNED'
  | 'ARRIVED_AT_PICKUP'
  | 'PICKED_UP'
  | 'IN_TRANSIT'
  | 'STARTED'
  | 'COMPLETED'
  | 'CANCELLED'
  | string

export interface DriverRideItem {
  ride_id: string
  customer_id: string
  vehicle_type_id: string | null
  pickup: { lat: number; lng: number; address?: string }
  drop: { lat: number; lng: number; address?: string }
  distance_km: number
  duration_min: number | null
  fare: number
  payment_mode: 'ONLINE' | 'CASH' | string
  payment_status: 'PENDING' | 'SUCCESS' | 'FAILED' | string
  otp_verified: boolean
  status: RideLifecycleStatus
  createdAt?: string
  updatedAt?: string
}

export interface DriverRideDetails {
  ride: DriverRideItem & {
    finance_processed?: boolean
    otp?: number
    customer: {
      id: string
      name: string
      email: string
      phone: string | null
      is_blocked: boolean
    } | null
    driver: {
      id: string
      name: string
      email: string
      phone: string | null
      driver_status: string
      is_blocked: boolean
      driver_verification_status: string
    }
    vehicle_type: {
      id: string
      name: string
      description?: string
      icon?: string
      base_fare?: number
      per_km_rate?: number
      is_active?: boolean
    } | null
  }
}
