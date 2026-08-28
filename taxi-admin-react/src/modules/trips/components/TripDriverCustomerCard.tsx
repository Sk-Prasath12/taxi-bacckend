import type { TripParticipant } from '../types/trips.types'

interface TripDriverCustomerCardProps {
  driver: TripParticipant
  customer: TripParticipant
}

function TripDriverCustomerCard({ driver, customer }: TripDriverCustomerCardProps) {
  return (
    <section className="grid grid-cols-1 gap-4 xl:grid-cols-2">
      <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">Driver</h2>
        <div className="mt-4 space-y-2 text-sm text-gray-600">
          <p><span className="font-medium text-gray-900">Name:</span> {driver.name}</p>
          <p><span className="font-medium text-gray-900">Phone:</span> {driver.phone}</p>
          <p><span className="font-medium text-gray-900">Vehicle Type:</span> {driver.vehicleType ?? 'N/A'}</p>
          <p><span className="font-medium text-gray-900">Rating:</span> {driver.rating.toFixed(1)}</p>
        </div>
      </article>

      <article className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
        <h2 className="text-lg font-semibold text-gray-900">Customer</h2>
        <div className="mt-4 space-y-2 text-sm text-gray-600">
          <p><span className="font-medium text-gray-900">Name:</span> {customer.name}</p>
          <p><span className="font-medium text-gray-900">Phone:</span> {customer.phone}</p>
          <p><span className="font-medium text-gray-900">Rating:</span> {customer.rating.toFixed(1)}</p>
        </div>
      </article>
    </section>
  )
}

export default TripDriverCustomerCard
