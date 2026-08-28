export type VehicleTypeStatus = 'Active' | 'Inactive'

export interface VehicleType {
  id: string
  typeName: string
  baseFare: number
  perKmFare: number
  passengerCapacity: number
  status: VehicleTypeStatus
}

export interface VehicleTypePayload {
  typeName: string
  baseFare: number
  perKmFare: number
  passengerCapacity: number
  status: VehicleTypeStatus
}

export interface DriverVehicle {
  id: string
  vehicleNumber: string
  vehicleType: string
  driverId: string
  driverName: string
  driverPhone: string
  driverEmail: string
  driverRating: number
  registrationDate: string
  passengerCapacity: number
  status: 'Active' | 'Inactive'
}

export interface VehicleDocuments {
  vehiclePhoto: string
  rcBook: string
  insurance: string
  permit: string
}

export interface VehicleStats {
  totalTrips: number
  completedTrips: number
  cancelledTrips: number
}

export interface VehicleDetails extends DriverVehicle {
  documents: VehicleDocuments
  stats: VehicleStats
}
