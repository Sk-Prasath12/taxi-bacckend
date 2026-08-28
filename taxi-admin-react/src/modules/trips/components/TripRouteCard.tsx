import type { TripRouteInfo } from '../types/trips.types'

interface TripRouteCardProps {
  route: TripRouteInfo
}

function TripRouteCard({ route }: TripRouteCardProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Trip Route</h2>
      <div className="mt-4 space-y-2 text-sm text-gray-600">
        <p><span className="font-medium text-gray-900">Pickup Location:</span> {route.pickupLocation}</p>
        <p><span className="font-medium text-gray-900">Drop Location:</span> {route.dropLocation}</p>
        <p><span className="font-medium text-gray-900">Distance:</span> {route.distanceKm} km</p>
        <p><span className="font-medium text-gray-900">Trip Duration:</span> {route.durationMinutes} mins</p>
      </div>
    </section>
  )
}

export default TripRouteCard
