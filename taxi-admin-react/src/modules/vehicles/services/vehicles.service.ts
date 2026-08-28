import type { Driver } from '../../drivers/types/drivers.types'
import { getDriverById, getDrivers } from '../../drivers/services/drivers.service'
import type { DriverVehicle, VehicleDetails, VehicleType, VehicleTypePayload, VehicleTypeStatus } from '../types/vehicles.types'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'

const MOCK_DELAY_MS = 220

let vehicleTypes: VehicleType[] = [
  { id: 'vt-1', typeName: 'Bike', baseFare: 10, perKmFare: 10, passengerCapacity: 1, status: 'Active' },
  { id: 'vt-2', typeName: 'Auto', baseFare: 20, perKmFare: 20, passengerCapacity: 3, status: 'Active' },
  { id: 'vt-3', typeName: 'Mini', baseFare: 30, perKmFare: 30, passengerCapacity: 4, status: 'Active' },
  { id: 'vt-4', typeName: 'Sedan', baseFare: 40, perKmFare: 40, passengerCapacity: 4, status: 'Active' },
  { id: 'vt-5', typeName: 'SUV', baseFare: 50, perKmFare: 50, passengerCapacity: 6, status: 'Active' },
  { id: 'vt-6', typeName: 'Premium Sedan', baseFare: 60, perKmFare: 60, passengerCapacity: 4, status: 'Active' },
  { id: 'vt-7', typeName: 'Premium SUV', baseFare: 70, perKmFare: 70, passengerCapacity: 7, status: 'Active' },
  { id: 'vt-8', typeName: 'XL', baseFare: 80, perKmFare: 80, passengerCapacity: 12, status: 'Active' },
  { id: 'vt-9', typeName: 'Electric', baseFare: 90, perKmFare: 90, passengerCapacity: 4, status: 'Active' },
  { id: 'vt-10', typeName: 'Accessible', baseFare: 100, perKmFare: 100, passengerCapacity: 4, status: 'Active' },
]

const vehicles: DriverVehicle[] = [
  {
    id: 'v-1',
    vehicleNumber: 'KA01AB1234',
    vehicleType: 'Sedan',
    driverId: 'd1',
    driverName: 'John Doe',
    driverPhone: '+91 98765 40001',
    driverEmail: 'john.doe@example.com',
    driverRating: 4.7,
    registrationDate: '2024-05-14',
    passengerCapacity: 4,
    status: 'Active',
  },
  {
    id: 'v-2',
    vehicleNumber: 'KA03CD9876',
    vehicleType: 'SUV',
    driverId: 'd2',
    driverName: 'Michael Ross',
    driverPhone: '+91 98765 40002',
    driverEmail: 'michael.ross@example.com',
    driverRating: 4.8,
    registrationDate: '2023-11-02',
    passengerCapacity: 6,
    status: 'Active',
  },
  {
    id: 'v-3',
    vehicleNumber: 'KA05EF7623',
    vehicleType: 'Mini',
    driverId: 'd3',
    driverName: 'Nikhil Verma',
    driverPhone: '+91 98765 40003',
    driverEmail: 'nikhil.verma@example.com',
    driverRating: 4.5,
    registrationDate: '2025-01-09',
    passengerCapacity: 4,
    status: 'Active',
  },
  {
    id: 'v-4',
    vehicleNumber: 'KA09GH3312',
    vehicleType: 'Auto',
    driverId: 'd4',
    driverName: 'Faizan Ali',
    driverPhone: '+91 98765 40004',
    driverEmail: 'faizan.ali@example.com',
    driverRating: 4.4,
    registrationDate: '2024-07-21',
    passengerCapacity: 3,
    status: 'Active',
  },
  {
    id: 'v-5',
    vehicleNumber: 'KA11JK8841',
    vehicleType: 'Bike',
    driverId: 'd5',
    driverName: 'David Singh',
    driverPhone: '+91 98765 40005',
    driverEmail: 'david.singh@example.com',
    driverRating: 4.3,
    registrationDate: '2025-02-18',
    passengerCapacity: 1,
    status: 'Inactive',
  },
]

const vehicleDetailsById: Record<string, VehicleDetails> = {
  'v-1': {
    ...vehicles[0],
    documents: {
      vehiclePhoto: 'https://images.unsplash.com/photo-1549924231-f129b911e442?w=900&q=80',
      rcBook: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=900&q=80',
      insurance: 'https://images.unsplash.com/photo-1450101499163-c8848c66ca85?w=900&q=80',
      permit: 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=900&q=80',
    },
    stats: {
      totalTrips: 1240,
      completedTrips: 1188,
      cancelledTrips: 52,
    },
  },
  'v-2': {
    ...vehicles[1],
    documents: {
      vehiclePhoto: 'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=900&q=80',
      rcBook: 'https://images.unsplash.com/photo-1589994965851-a8f479c573a9?w=900&q=80',
      insurance: 'https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=900&q=80',
      permit: 'https://images.unsplash.com/photo-1586486855514-8c633cc6fd38?w=900&q=80',
    },
    stats: {
      totalTrips: 980,
      completedTrips: 925,
      cancelledTrips: 55,
    },
  },
}

function wait<T>(value: T): Promise<T> {
  return new Promise((resolve) => {
    setTimeout(() => resolve(value), MOCK_DELAY_MS)
  })
}

function displayVehicleName(name: string): string {
  const aliases: Record<string, string> = {
    'Small 5 Seater Car': 'Mini',
    '5 Seater': 'Mini',
    'Big 7 Seater Car': 'Premium SUV',
    '7 Seater': 'Premium SUV',
    Motorbike: 'Bike',
    'Two Wheeler': 'Bike',
    Hatchback: 'Mini',
    Luxury: 'Premium Sedan',
    Van: 'XL',
    Hybrid: 'Electric',
  }
  return aliases[name] ?? name
}

export async function getVehicleTypes(): Promise<VehicleType[]> {
  const urls = [`${ADMIN_API_BASE_URL}/vehicle-types`, `${ADMIN_API_BASE_URL}/vehicle-types/active`]
  for (const url of urls) {
    try {
      const response = await fetch(url)
      const payload = await response.json().catch(() => null)
      if (!response.ok) continue
      const rows = Array.isArray(payload)
        ? payload
        : Array.isArray((payload as { data?: unknown[] } | null)?.data)
          ? (payload as { data: unknown[] }).data
          : null
      if (!rows) continue
      return rows
        .filter((row): row is Record<string, unknown> => row != null && typeof row === 'object')
        .map((row) => ({
          id: String(row.id ?? row._id ?? ''),
          typeName: displayVehicleName(String(row.name ?? row.typeName ?? 'Vehicle')),
          baseFare: Number(row.base_fare ?? row.baseFare ?? 0),
          perKmFare: Number(row.per_km_rate ?? row.perKmFare ?? 0),
          passengerCapacity: Number(row.max_passengers ?? row.passengerCapacity ?? 1),
          status: (row.is_active === false ? 'Inactive' : 'Active') as VehicleTypeStatus,
        }))
        .filter((row) => row.id.length > 0)
    } catch {
      // try next url
    }
  }
  return wait([...vehicleTypes])
}

export async function createVehicleType(payload: VehicleTypePayload): Promise<VehicleType> {
  const newType: VehicleType = {
    id: `vt-${Date.now()}`,
    ...payload,
  }
  vehicleTypes = [newType, ...vehicleTypes]
  return wait(newType)
}

export async function updateVehicleType(vehicleTypeId: string, payload: VehicleTypePayload): Promise<void> {
  vehicleTypes = vehicleTypes.map((vehicleType) =>
    vehicleType.id === vehicleTypeId ? { ...vehicleType, ...payload } : vehicleType,
  )
  return wait(undefined)
}

export async function deleteVehicleType(vehicleTypeId: string): Promise<void> {
  vehicleTypes = vehicleTypes.filter((vehicleType) => vehicleType.id !== vehicleTypeId)
  return wait(undefined)
}

function mapDriverToVehicle(driver: Driver): DriverVehicle {
  return {
    id: driver.id,
    vehicleNumber: driver.vehicleNumber && driver.vehicleNumber !== 'N/A' ? driver.vehicleNumber : '—',
    vehicleType: displayVehicleName(driver.vehicleType || '—'),
    driverId: driver.id,
    driverName: driver.name,
    driverPhone: driver.phone,
    driverEmail: driver.email,
    driverRating: driver.rating,
    registrationDate: driver.joinDate,
    passengerCapacity: 0,
    status: driver.status === 'Blocked' || driver.status === 'Inactive' ? 'Inactive' : 'Active',
  }
}

export async function getVehicles(): Promise<DriverVehicle[]> {
  try {
    const drivers = await getDrivers()
    return drivers
      .filter((driver) => driver.vehicleNumber && driver.vehicleNumber !== 'N/A')
      .map(mapDriverToVehicle)
  } catch {
    return wait([...vehicles])
  }
}

export async function getVehicleById(vehicleId: string): Promise<VehicleDetails | null> {
  try {
    const driver = await getDriverById(vehicleId)
    if (!driver) return null
    const mapped = mapDriverToVehicle(driver)
    const photo =
      driver.documents.find((doc) => doc.type === 'vehiclePhoto')?.imageUrl ??
      driver.documents.find((doc) => doc.type === 'vehicleRC')?.imageUrl ??
      ''
    return {
      ...mapped,
      documents: {
        vehiclePhoto: photo,
        rcBook: driver.documents.find((doc) => doc.type === 'vehicleRC')?.imageUrl ?? '',
        insurance: driver.documents.find((doc) => doc.type === 'insurance')?.imageUrl ?? '',
        permit: '',
      },
      stats: {
        totalTrips: driver.stats.totalTrips,
        completedTrips: driver.stats.completedTrips,
        cancelledTrips: driver.stats.cancelledTrips,
      },
    }
  } catch {
    const matched = vehicles.find((vehicle) => vehicle.id === vehicleId)
    if (!matched) return null
    return wait(
      vehicleDetailsById[vehicleId] ?? {
        ...matched,
        documents: {
          vehiclePhoto: '',
          rcBook: '',
          insurance: '',
          permit: '',
        },
        stats: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0 },
      },
    )
  }
}
