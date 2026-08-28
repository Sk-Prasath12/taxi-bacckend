import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import type { Customer, CustomerStatus } from '../types/customers.types'

type CustomerFilter = 'All Customers' | CustomerStatus

interface CustomersTableProps {
  customers: Customer[]
}

const ITEMS_PER_PAGE = 10

function CustomersTable({ customers }: CustomersTableProps) {
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<CustomerFilter>('All Customers')
  const [page, setPage] = useState(1)

  const filteredCustomers = useMemo(() => {
    const query = search.trim().toLowerCase()

    return customers.filter((customer) => {
      const matchFilter =
        filter === 'All Customers' ? true : customer.status === filter
      const matchQuery =
        !query ||
        customer.name.toLowerCase().includes(query) ||
        customer.phone.toLowerCase().includes(query)

      return matchFilter && matchQuery
    })
  }, [customers, filter, search])

  const totalPages = Math.max(1, Math.ceil(filteredCustomers.length / ITEMS_PER_PAGE))
  const paginatedCustomers = filteredCustomers.slice((page - 1) * ITEMS_PER_PAGE, page * ITEMS_PER_PAGE)

  const statusClass = (status: CustomerStatus) =>
    status === 'Active'
      ? 'bg-green-100 text-green-700'
      : 'bg-red-100 text-red-700'

  const onFilterChange = (value: CustomerFilter) => {
    setFilter(value)
    setPage(1)
  }

  const onSearchChange = (value: string) => {
    setSearch(value)
    setPage(1)
  }

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="mb-4 flex flex-col gap-3 md:flex-row">
        <input
          value={search}
          onChange={(event) => onSearchChange(event.target.value)}
          placeholder="Search by name or phone"
          className="h-10 w-full rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
        />
        <select
          value={filter}
          onChange={(event) => onFilterChange(event.target.value as CustomerFilter)}
          className="h-10 rounded-lg border border-gray-200 px-3 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200 md:w-52"
        >
          <option value="All Customers">All Customers</option>
          <option value="Active">Active</option>
          <option value="Blocked">Blocked</option>
        </select>
      </div>

      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Customer Name',
                'Phone',
                'Email',
                'Total Trips',
                'Rating',
                'Join Date',
                'Status',
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
            {paginatedCustomers.map((customer) => (
              <tr key={customer.id} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{customer.name}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{customer.phone}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{customer.email}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{customer.stats.totalTrips}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{customer.stats.rating.toFixed(1)}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{customer.joinDate}</td>
                <td className="px-3 py-3 text-sm">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(customer.status)}`}>
                    {customer.status}
                  </span>
                </td>
                <td className="px-3 py-3 text-sm">
                  <Link
                    to={`/admin/customers/${customer.id}`}
                    className="font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
                  >
                    View Customer
                  </Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {paginatedCustomers.map((customer) => (
            <article key={customer.id} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="text-base font-semibold text-gray-900">{customer.name}</h3>
                <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(customer.status)}`}>
                  {customer.status}
                </span>
              </div>
              <p className="mt-2 text-sm text-gray-500">{customer.phone}</p>
              <p className="mt-1 text-sm text-gray-500">{customer.email}</p>
              <p className="mt-1 text-sm text-gray-500">Trips: {customer.stats.totalTrips}</p>
              <p className="mt-1 text-sm text-gray-500">Rating: {customer.stats.rating.toFixed(1)}</p>
              <Link
                to={`/admin/customers/${customer.id}`}
                className="mt-3 inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
              >
                View Customer
              </Link>
            </article>
          ))}
        </div>
      </div>

      <div className="mt-4 flex items-center justify-between gap-3">
        <button
          type="button"
          onClick={() => setPage((prev) => Math.max(1, prev - 1))}
          disabled={page === 1}
          className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
        >
          Previous
        </button>
        <span className="text-sm text-gray-500">
          Page {page} of {totalPages}
        </span>
        <button
          type="button"
          onClick={() => setPage((prev) => Math.min(totalPages, prev + 1))}
          disabled={page === totalPages}
          className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-sm text-gray-900 transition hover:bg-gray-50 disabled:cursor-not-allowed disabled:opacity-60"
        >
          Next
        </button>
      </div>
    </section>
  )
}

export default CustomersTable
