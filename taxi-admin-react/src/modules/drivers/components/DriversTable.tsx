import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import DriverOnlineBadge from './DriverOnlineBadge'
import { isDriverCurrentlyOnline } from '../utils/driverOnlineStatus'
import type { Driver, DriverStatus } from '../types/drivers.types'

type DriverFilter = 'All' | DriverStatus | 'Online'

interface DriversTableProps {
  drivers: Driver[]
}

interface StatusBadgeProps {
  status: DriverStatus
}

function StatusBadge({ status }: StatusBadgeProps) {
  const statusClass =
    status === 'Active'
      ? 'bg-green-100 text-green-700'
      : status === 'Inactive'
        ? 'bg-gray-100 text-gray-600'
        : 'bg-yellow-100 text-amber-800'

  return (
    <span className={`inline-flex rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass}`}>
      {status}
    </span>
  )
}

interface SearchInputProps {
  value: string
  onChange: (value: string) => void
}

function SearchInput({ value, onChange }: SearchInputProps) {
  return (
    <input
      value={value}
      onChange={(event) => onChange(event.target.value)}
      placeholder="Search by driver name or phone"
      className="h-10 w-full rounded-lg border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
    />
  )
}

interface FilterDropdownProps {
  value: DriverFilter
  onChange: (value: DriverFilter) => void
}

function FilterDropdown({ value, onChange }: FilterDropdownProps) {
  const options: DriverFilter[] = ['All', 'Online', 'Active', 'Inactive', 'Pending']

  return (
    <select
      className="h-10 min-w-44 rounded-lg border border-gray-200 bg-white px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
      value={value}
      onChange={(event) => onChange(event.target.value as DriverFilter)}
    >
      {options.map((option) => (
        <option key={option} value={option}>
          {option === 'All' ? 'All Drivers' : option}
        </option>
      ))}
    </select>
  )
}

interface PaginationProps {
  page: number
  totalPages: number
  onChange: (next: number) => void
}

function Pagination({ page, totalPages, onChange }: PaginationProps) {
  return (
    <div className="drivers-pagination">
      <button
        type="button"
        className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
        onClick={() => onChange(page - 1)}
        disabled={page === 1}
      >
        Previous
      </button>
      <span className="text-sm text-gray-500">
        Page {page} of {totalPages}
      </span>
      <button
        type="button"
        className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
        onClick={() => onChange(page + 1)}
        disabled={page === totalPages}
      >
        Next
      </button>
    </div>
  )
}

const ITEMS_PER_PAGE = 10

function DriversTable({ drivers }: DriversTableProps) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<DriverFilter>('All')
  const [page, setPage] = useState(1)

  const filteredDrivers = useMemo(() => {
    const query = search.trim().toLowerCase()

    return drivers.filter((driver) => {
      const matchesFilter =
        filter === 'All'
          ? true
          : filter === 'Online'
            ? isDriverCurrentlyOnline(driver.onlineMode)
            : driver.status === filter
      const matchesQuery =
        !query ||
        driver.name.toLowerCase().includes(query) ||
        driver.phone.toLowerCase().includes(query)

      return matchesFilter && matchesQuery
    })
  }, [drivers, filter, search])

  const totalPages = Math.max(1, Math.ceil(filteredDrivers.length / ITEMS_PER_PAGE))
  const paginatedDrivers = filteredDrivers.slice((page - 1) * ITEMS_PER_PAGE, page * ITEMS_PER_PAGE)

  const handleFilterChange = (nextFilter: DriverFilter) => {
    setFilter(nextFilter)
    setPage(1)
  }

  const handleSearchChange = (nextSearch: string) => {
    setSearch(nextSearch)
    setPage(1)
  }

  const handlePageChange = (nextPage: number) => {
    if (nextPage < 1 || nextPage > totalPages) {
      return
    }
    setPage(nextPage)
  }

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="mb-4 flex flex-col gap-3 sm:flex-row">
        <SearchInput value={search} onChange={handleSearchChange} />
        <FilterDropdown value={filter} onChange={handleFilterChange} />
      </div>

      <div className="overflow-x-auto">
        <table className="hidden min-w-full border-collapse md:table">
          <thead>
            <tr>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Driver</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Phone</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Vehicle Type</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Account</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Online mode</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Total Trips</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Rating</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Join Date</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Actions</th>
            </tr>
          </thead>
          <tbody>
            {paginatedDrivers.map((driver) => (
              <tr key={driver.id} className="transition hover:bg-yellow-50">
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-900">{driver.name}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{driver.phone}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{driver.vehicleType}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                  <StatusBadge status={driver.status} />
                </td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                  <DriverOnlineBadge status={driver.onlineMode} />
                </td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{driver.totalTrips}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{driver.rating > 0 ? driver.rating.toFixed(1) : '-'}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{driver.joinDate}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm">
                  <Link
                    to={`/admin/drivers/${driver.id}`}
                    className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                  >
                    View Driver
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {paginatedDrivers.map((driver) => (
            <article key={driver.id} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="m-0 text-base font-semibold text-gray-900">{driver.name}</h3>
                <div className="flex flex-col items-end gap-1">
                  <StatusBadge status={driver.status} />
                  <DriverOnlineBadge status={driver.onlineMode} />
                </div>
              </div>
              <p className="mt-2 text-sm text-gray-500">{driver.phone}</p>
              <p className="mt-1 text-sm text-gray-500">{driver.vehicleType}</p>
              <p className="mt-1 text-sm text-gray-500">Trips: {driver.totalTrips}</p>
              <p className="mt-1 text-sm text-gray-500">Rating: {driver.rating > 0 ? driver.rating.toFixed(1) : '-'}</p>
              <Link
                to={`/admin/drivers/${driver.id}`}
                className="mt-3 inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                View Driver
              </Link>
            </article>
          ))}
        </div>
      </div>

      <div className="mt-4">
        <Pagination page={page} totalPages={totalPages} onChange={handlePageChange} />
      </div>
    </section>
  )
}

export default DriversTable
