import type { DriverEarningsRow, RevenueRow } from '../types/payments.types'

interface DriverEarningsTableProps {
  rows: DriverEarningsRow[]
}

export function DriverEarningsTable({ rows }: DriverEarningsTableProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {['Driver Name', 'Total Trips', 'Total Earnings', 'Commission Deducted', 'Net Earnings'].map(
                (header) => (
                  <th
                    key={header}
                    className="px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500"
                  >
                    {header}
                  </th>
                ),
              )}
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {rows.map((row) => (
              <tr key={row.driverId} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{row.driverName}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{row.totalTrips}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {row.totalEarnings.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm text-gray-700">
                  ₹ {row.commissionDeducted.toLocaleString('en-IN')}
                </td>
                <td className="px-3 py-3 text-sm font-semibold text-gray-900">
                  ₹ {row.netEarnings.toLocaleString('en-IN')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {rows.map((row) => (
            <article key={row.driverId} className="rounded-xl border border-gray-200 bg-white p-4">
              <h3 className="text-base font-semibold text-gray-900">{row.driverName}</h3>
              <p className="mt-2 text-sm text-gray-500">Trips: {row.totalTrips}</p>
              <p className="mt-1 text-sm text-gray-500">Total: ₹ {row.totalEarnings.toLocaleString('en-IN')}</p>
              <p className="mt-1 text-sm text-gray-500">
                Commission: ₹ {row.commissionDeducted.toLocaleString('en-IN')}
              </p>
              <p className="mt-1 text-sm font-semibold text-gray-900">
                Net: ₹ {row.netEarnings.toLocaleString('en-IN')}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}

interface RevenueTableProps {
  rows: RevenueRow[]
}

export function RevenueTable({ rows }: RevenueTableProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-6 shadow-sm">
      <div className="overflow-x-auto">
        <table className="hidden w-full min-w-[980px] divide-y divide-gray-200 md:table">
          <thead>
            <tr>
              {['Date', 'Total Trips', 'Driver Earnings', 'Admin Commission', 'Total Revenue'].map((header) => (
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
              <tr key={row.date} className="transition hover:bg-gray-50">
                <td className="px-3 py-3 text-sm text-gray-900">{row.date}</td>
                <td className="px-3 py-3 text-sm text-gray-700">{row.totalTrips}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {row.driverEarnings.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm text-gray-700">₹ {row.adminCommission.toLocaleString('en-IN')}</td>
                <td className="px-3 py-3 text-sm font-semibold text-gray-900">
                  ₹ {row.totalRevenue.toLocaleString('en-IN')}
                </td>
              </tr>
            ))}
          </tbody>
        </table>

        <div className="grid gap-3 md:hidden">
          {rows.map((row) => (
            <article key={row.date} className="rounded-xl border border-gray-200 bg-white p-4">
              <h3 className="text-base font-semibold text-gray-900">{row.date}</h3>
              <p className="mt-2 text-sm text-gray-500">Trips: {row.totalTrips}</p>
              <p className="mt-1 text-sm text-gray-500">
                Driver Earnings: ₹ {row.driverEarnings.toLocaleString('en-IN')}
              </p>
              <p className="mt-1 text-sm text-gray-500">
                Admin Commission: ₹ {row.adminCommission.toLocaleString('en-IN')}
              </p>
              <p className="mt-1 text-sm font-semibold text-gray-900">
                Revenue: ₹ {row.totalRevenue.toLocaleString('en-IN')}
              </p>
            </article>
          ))}
        </div>
      </div>
    </section>
  )
}
