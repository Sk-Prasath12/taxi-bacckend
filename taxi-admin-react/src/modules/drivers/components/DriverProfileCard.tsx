import type { Driver } from '../types/drivers.types'
import DriverOnlineBadge from './DriverOnlineBadge'

interface DriverProfileCardProps {
  driver: Driver
}

function DriverProfileCard({ driver }: DriverProfileCardProps) {
  const statusClass =
    driver.status === 'Active'
      ? 'bg-green-100 text-green-700'
      : driver.status === 'Inactive'
        ? 'bg-gray-100 text-gray-600'
        : 'bg-yellow-100 text-amber-800'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="flex flex-col items-start gap-4 md:flex-row md:items-center">
        <div className="flex h-14 w-14 items-center justify-center rounded-full bg-yellow-200 text-2xl font-bold text-amber-800">
          {driver.name.charAt(0)}
        </div>
        <div>
          <h2 className="text-xl font-semibold text-gray-900">{driver.name}</h2>
          <p className="text-sm text-gray-500">{driver.phone}</p>
          <p className="text-sm text-gray-500">{driver.email}</p>
          <p className="text-sm text-gray-500">Joined: {driver.joinDate}</p>
        </div>
        <div className="flex flex-col items-start gap-2 md:ml-auto md:items-end">
          <span className={`inline-flex rounded-full px-3 py-1 text-xs font-semibold ${statusClass}`}>
            Account: {driver.status}
          </span>
          <DriverOnlineBadge status={driver.onlineMode} />
        </div>
      </div>

      <div className="mt-5 grid grid-cols-1 gap-4 md:grid-cols-2">
        <article className="rounded-lg border border-gray-200 bg-white p-4">
          <h3 className="text-base font-semibold text-gray-900">Vehicle Information</h3>
          <p className="mt-2 text-sm text-gray-500">Vehicle Type: {driver.vehicleType}</p>
          <p className="mt-1 text-sm text-gray-500">Vehicle Number: {driver.vehicleNumber}</p>
          <p className="mt-1 text-sm text-gray-500">Vehicle Model: {driver.vehicleModel}</p>
        </article>

        <article className="rounded-lg border border-gray-200 bg-white p-4">
          <h3 className="text-base font-semibold text-gray-900">Statistics</h3>
          <p className="mt-2 text-sm text-gray-500">Total Trips: {driver.stats.totalTrips}</p>
          <p className="mt-1 text-sm text-gray-500">Completed Trips: {driver.stats.completedTrips}</p>
          <p className="mt-1 text-sm text-gray-500">Cancelled Trips: {driver.stats.cancelledTrips}</p>
          <p className="mt-1 text-sm text-gray-500">
            Rating: {driver.stats.rating > 0 ? driver.stats.rating.toFixed(1) : '-'}
          </p>
        </article>
      </div>
    </section>
  )
}

export default DriverProfileCard
