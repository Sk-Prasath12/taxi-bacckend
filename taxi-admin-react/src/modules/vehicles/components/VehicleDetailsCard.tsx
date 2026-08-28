import type { VehicleDetails } from '../types/vehicles.types'

interface VehicleDetailsCardProps {
  vehicle: VehicleDetails
}

function VehicleDetailsCard({ vehicle }: VehicleDetailsCardProps) {
  const statusClass =
    vehicle.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-700'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Vehicle Information</h2>
      <div className="mt-4 space-y-2 text-sm text-gray-600">
        <p><span className="font-medium text-gray-900">Vehicle Number:</span> {vehicle.vehicleNumber}</p>
        <p><span className="font-medium text-gray-900">Vehicle Type:</span> {vehicle.vehicleType}</p>
        <p><span className="font-medium text-gray-900">Registration Date:</span> {vehicle.registrationDate}</p>
        <p><span className="font-medium text-gray-900">Passenger Capacity:</span> {vehicle.passengerCapacity}</p>
        <p>
          <span className="font-medium text-gray-900">Status:</span>{' '}
          <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass}`}>
            {vehicle.status}
          </span>
        </p>
      </div>
    </section>
  )
}

export default VehicleDetailsCard
