import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import TripStatusBadge from './TripStatusBadge'
import type { TripListItem } from '../types/trips.types'

interface TripsTableProps {
  trips: TripListItem[]
}

type TripFilterTab = 'All Trips' | 'Active Trips' | 'Completed Trips' | 'Cancelled Trips'

const filterTabs: TripFilterTab[] = ['All Trips', 'Active Trips', 'Completed Trips', 'Cancelled Trips']

function TripsTable({ trips }: TripsTableProps) {
  const [activeTab, setActiveTab] = useState<TripFilterTab>('All Trips')
  const [search, setSearch] = useState('')

  const filteredTrips = useMemo(() => {
    const query = search.trim().toLowerCase()

    return trips.filter((trip) => {
      const normalizedStatus = `${trip.status} Trips` as TripFilterTab
      const matchTab = activeTab === 'All Trips' ? true : normalizedStatus === activeTab
      const matchQuery =
        !query ||
        trip.tripId.toLowerCase().includes(query) ||
        trip.driverName.toLowerCase().includes(query) ||
        trip.customerName.toLowerCase().includes(query)

      return matchTab && matchQuery
    })
  }, [trips, activeTab, search])

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-wrap gap-2">
        {filterTabs.map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setActiveTab(tab)}
            className={`rounded-lg px-4 py-2 text-sm font-medium transition ${
              activeTab === tab
                ? 'bg-yellow-400 text-black'
                : 'border border-gray-200 bg-white text-gray-700 hover:bg-yellow-300'
            }`}
          >
            {tab}
          </button>
        ))}
      </div>

      <input
        value={search}
        onChange={(event) => setSearch(event.target.value)}
        placeholder="Search by Trip ID, Driver Name or Customer Name"
        className="mb-4 h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
      />

      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[1080px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Trip ID',
                'Customer',
                'Driver',
                'Pickup Location',
                'Drop Location',
                'Fare',
                'Status',
                'Date',
                'Actions',
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
            {filteredTrips.map((trip) => (
              <tr key={trip.tripId} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{trip.tripId}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.customerName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.pickupLocation}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.dropLocation}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {trip.fare.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm">
                  <TripStatusBadge status={trip.status} />
                </td>
                <td className="px-3 py-3 text-sm text-gray-700">{trip.date}</td>
                <td className="px-3 py-3 text-sm">
                  <Link
                    to={`/admin/trips/${trip.tripId}`}
                    className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                  >
                    View Trip
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {filteredTrips.map((trip) => (
            <article key={trip.tripId} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="text-base font-semibold text-gray-900">{trip.tripId}</h3>
                <TripStatusBadge status={trip.status} />
              </div>
              <p className="mt-2 text-sm text-gray-500">Customer: {trip.customerName}</p>
              <p className="mt-1 text-sm text-gray-500">Driver: {trip.driverName}</p>
              <p className="mt-1 text-sm text-gray-500">Pickup: {trip.pickupLocation}</p>
              <p className="mt-1 text-sm text-gray-500">Drop: {trip.dropLocation}</p>
              <p className="mt-1 text-sm text-gray-500">Fare: ₹ {trip.fare.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">Date: {trip.date}</p>
              <Link
                to={`/admin/trips/${trip.tripId}`}
                className="mt-3 inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                View Trip
              </Link>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default TripsTable
