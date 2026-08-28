import type { CustomerTrip } from '../types/customers.types'

interface CustomerTripsTableProps {
  trips: CustomerTrip[]
}

function CustomerTripsTable({ trips }: CustomerTripsTableProps) {
  const statusClass = (status: CustomerTrip['status']) =>
    status === 'Completed'
      ? 'bg-green-100 text-green-700'
      : status === 'Cancelled'
        ? 'bg-red-100 text-red-700'
        : 'bg-yellow-100 text-amber-800'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <h2 className="text-lg font-semibold text-gray-900">Trip History</h2>
      <div className="mt-4 overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Trip ID',
                'Driver Name',
                'Pickup Location',
                'Drop Location',
                'Fare',
                'Date',
                'Status',
              ].map((header) => (
                <th
                  key={header}
                  className="px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500"
                >
                  {header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {trips.map((trip) => (
              <tr key={trip.id} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{trip.id}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.pickupLocation}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.dropLocation}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {trip.fare.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.date}</td>
                <td className="px-3 py-3 text-sm">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(trip.status)}`}>
                    {trip.status}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {trips.map((trip) => (
            <article key={trip.id} className="rounded-xl border border-gray-200 bg-white p-4">
              <h3 className="text-base font-semibold text-gray-900">{trip.id}</h3>
              <p className="mt-2 text-sm text-gray-500">Driver: {trip.driverName}</p>
              <p className="mt-1 text-sm text-gray-500">Pickup: {trip.pickupLocation}</p>
              <p className="mt-1 text-sm text-gray-500">Drop: {trip.dropLocation}</p>
              <p className="mt-1 text-sm text-gray-500">Fare: ₹ {trip.fare.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">Date: {trip.date}</p>
              <div className="mt-2">
                <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(trip.status)}`}>
                  {trip.status}
                </span>
              </div>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default CustomerTripsTable
