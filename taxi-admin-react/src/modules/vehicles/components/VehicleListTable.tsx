import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import type { DriverVehicle } from '../types/vehicles.types'

type VehicleFilter =
  | 'All Vehicles'
  | 'Bike'
  | 'Auto'
  | 'Mini'
  | 'Sedan'
  | 'SUV'
  | 'Premium Sedan'
  | 'Premium SUV'
  | 'XL'
  | 'Electric'
  | 'Accessible'

interface VehicleListTableProps {
  vehicles: DriverVehicle[]
}

function VehicleListTable({ vehicles }: VehicleListTableProps) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<VehicleFilter>('All Vehicles')

  const filteredVehicles = useMemo(() => {
    const query = search.trim().toLowerCase()

    return vehicles.filter((vehicle) => {
      const matchFilter = filter === 'All Vehicles' ? true : vehicle.vehicleType === filter
      const matchQuery =
        !query ||
        vehicle.vehicleNumber.toLowerCase().includes(query) ||
        vehicle.driverName.toLowerCase().includes(query)

      return matchFilter && matchQuery
    })
  }, [vehicles, search, filter])

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-col gap-3 md:flex-row">
        <input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Search by vehicle number or driver name"
          className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
        />
        <select
          value={filter}
          onChange={(event) => setFilter(event.target.value as VehicleFilter)}
          className="h-10 rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200 md:w-48"
        >
          <option value="All Vehicles">All Vehicles</option>
          <option value="Bike">Bike</option>
          <option value="Auto">Auto</option>
          <option value="Mini">Mini</option>
          <option value="Sedan">Sedan</option>
          <option value="SUV">SUV</option>
          <option value="Premium Sedan">Premium Sedan</option>
          <option value="Premium SUV">Premium SUV</option>
          <option value="XL">XL</option>
          <option value="Electric">Electric</option>
          <option value="Accessible">Accessible</option>
        </select>
      </div>

      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Vehicle Number',
                'Vehicle Type',
                'Driver Name',
                'Driver Phone',
                'Driver Rating',
                'Registration Date',
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
            {filteredVehicles.map((vehicle) => (
              <tr key={vehicle.id} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm">
                  <Link
                    to={`/admin/vehicles/${vehicle.id}`}
                    className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                  >
                    {vehicle.vehicleNumber}
                  </Link>
                </td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicle.vehicleType}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicle.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicle.driverPhone}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicle.driverRating.toFixed(1)}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{vehicle.registrationDate}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {filteredVehicles.map((vehicle) => (
            <article key={vehicle.id} className="rounded-xl border border-gray-200 bg-white p-4">
              <Link
                to={`/admin/vehicles/${vehicle.id}`}
                className="text-base font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                {vehicle.vehicleNumber}
              </Link>
              <p className="mt-2 text-sm text-gray-500">Type: {vehicle.vehicleType}</p>
              <p className="mt-1 text-sm text-gray-500">Driver: {vehicle.driverName}</p>
              <p className="mt-1 text-sm text-gray-500">Phone: {vehicle.driverPhone}</p>
              <p className="mt-1 text-sm text-gray-500">Rating: {vehicle.driverRating.toFixed(1)}</p>
              <p className="mt-1 text-sm text-gray-500">Registered: {vehicle.registrationDate}</p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default VehicleListTable
