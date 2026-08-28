export type TripStatus = 'Active' | 'Completed' | 'Cancelled'

export interface TripListItem {
  tripId: string
  customerName: string
  driverName: string
  pickupLocation: string
  dropLocation: string
  fare: number
  status: TripStatus
  date: string
  paymentMode?: string
  paymentStatus?: string
  emergency?: boolean
}

export interface TripParticipant {
  name: string
  phone: string
  rating: number
  vehicleType?: string
}

export interface TripRouteInfo {
  pickupLocation: string
  dropLocation: string
  distanceKm: number
  durationMinutes: number
}

export interface TripFareBreakdownData {
  baseFare: number
  distanceFare: number
  timeFare: number
  taxes: number
  discount: number
  totalFare: number
}

export interface TripTimelineItem {
  label: string
  completed: boolean
}

export interface TripDetails {
  tripId: string
  status: TripStatus
  date: string
  fare: number
  paymentMode?: string
  paymentStatus?: string
  financeProcessed?: boolean
  emergencyAlerted?: boolean
  driver: TripParticipant
  customer: TripParticipant
  route: TripRouteInfo
  fareBreakdown: TripFareBreakdownData
  timeline: TripTimelineItem[]
}
