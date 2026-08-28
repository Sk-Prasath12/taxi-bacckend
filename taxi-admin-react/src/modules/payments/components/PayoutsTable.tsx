import type { DriverPayoutRow } from '../types/payments.types'

interface PayoutsTableProps {
  rows: DriverPayoutRow[]
  onPayDriver: (driverId: string) => Promise<void>
}

function PayoutsTable({ rows, onPayDriver }: PayoutsTableProps) {
  const statusClass = (status: DriverPayoutRow['status']) =>
    status === 'Paid' ? 'bg-green-100 text-green-700' : 'bg-yellow-100 text-yellow-700'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {[
                'Driver Name',
                'Total Earnings',
                'Pending Payout',
                'Last Payout Date',
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
            {rows.map((row) => (
              <tr key={row.driverId} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{row.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {row.totalEarnings.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {row.pendingPayout.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{row.lastPayoutDate}</td>
                <td className="px-3 py-3 text-sm">
                  <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(row.status)}`}>
                    {row.status}
                  </span>
                </td>
                <td className="px-3 py-3 text-sm">
                  <button
                    type="button"
                    onClick={() => onPayDriver(row.driverId)}
                    disabled={row.pendingPayout === 0}
                    className="rounded bg-yellow-400 px-3 py-1 text-sm font-semibold text-black transition hover:bg-yellow-300 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    Pay Driver
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {rows.map((row) => (
            <article key={row.driverId} className="rounded-xl border border-gray-200 bg-white p-4">
              <div className="flex items-start justify-between gap-3">
                <h3 className="text-base font-semibold text-gray-900">{row.driverName}</h3>
                <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass(row.status)}`}>
                  {row.status}
                </span>
              </div>
              <p className="mt-2 text-sm text-gray-500">Total: ₹ {row.totalEarnings.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">Pending: ₹ {row.pendingPayout.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">Last Payout: {row.lastPayoutDate}</p>
              <button
                type="button"
                onClick={() => onPayDriver(row.driverId)}
                disabled={row.pendingPayout === 0}
                className="mt-3 rounded bg-yellow-400 px-3 py-1 text-sm font-semibold text-black transition hover:bg-yellow-300 disabled:cursor-not-allowed disabled:opacity-60"
              >
                Pay Driver
              </button>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

export default PayoutsTable
