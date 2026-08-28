import type { DriverEarningEntry } from '../types/drivers.types'

interface DriverEarningsTableProps {
  earnings: DriverEarningEntry[]
}

function DriverEarningsTable({ earnings }: DriverEarningsTableProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <h2 className="mb-4 text-lg font-semibold text-gray-900">Earnings History</h2>
      <div className="overflow-x-auto">
        <table className="hidden min-w-full border-collapse md:table">
          <thead>
            <tr>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Date</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Trip ID</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Fare</th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Driver Earnings</th>
            </tr>
          </thead>
          <tbody>
            {earnings.map((entry) => (
              <tr key={entry.id} className="transition hover:bg-yellow-50">
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">{entry.date}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-900">{entry.tripId}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">₹ {entry.fare.toLocaleString('en-IN')}</td>
                <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">₹ {entry.driverEarnings.toLocaleString('en-IN')}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {earnings.map((entry) => (
            <article key={entry.id} className="rounded-lg border border-gray-200 bg-white p-4">
              <h3 className="text-base font-semibold text-gray-900">{entry.tripId}</h3>
              <p className="mt-2 text-sm text-gray-500">Date: {entry.date}</p>
              <p className="mt-1 text-sm text-gray-500">Fare: ₹ {entry.fare.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">
                Driver Earnings: ₹ {entry.driverEarnings.toLocaleString('en-IN')}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default DriverEarningsTable
