export type CustomerStatus = 'Active' | 'Blocked'

export interface CustomerStats {
  totalTrips: number
  completedTrips: number
  cancelledTrips: number
  rating: number
}

export interface Customer {
  id: string
  name: string
  phone: string
  email: string
  joinDate: string
  status: CustomerStatus
  stats: CustomerStats
}

export interface CustomerTrip {
  id: string
  driverName: string
  pickupLocation: string
  dropLocation: string
  fare: number
  date: string
  status: 'Completed' | 'Cancelled' | 'Ongoing'
}
