import { Link } from 'react-router-dom'
import type { VehicleDetails } from '../types/vehicles.types'

interface VehicleOwnerCardProps {
  vehicle: VehicleDetails
}

function VehicleOwnerCard({ vehicle }: VehicleOwnerCardProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Owner Details</h2>
      <div className="mt-4 space-y-2 text-sm text-gray-600">
        <p><span className="font-medium text-gray-900">Driver Name:</span> {vehicle.driverName}</p>
        <p><span className="font-medium text-gray-900">Driver Phone:</span> {vehicle.driverPhone}</p>
        <p><span className="font-medium text-gray-900">Driver Email:</span> {vehicle.driverEmail}</p>
        <p><span className="font-medium text-gray-900">Driver Rating:</span> {vehicle.driverRating.toFixed(1)}</p>
        <p><span className="font-medium text-gray-900">Total Trips:</span> {vehicle.stats.totalTrips}</p>
      </div>
      <Link
        to={`/admin/drivers/${vehicle.driverId}`}
        className="mt-4 inline-flex rounded-lg bg-yellow-400 px-4 py-2 text-sm font-semibold text-black transition hover:bg-yellow-300"
      >
        View Driver Profile
      </Link>
    </section>
  )
}

export default VehicleOwnerCard
