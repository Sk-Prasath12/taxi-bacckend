import DriverOnlineBadge from '../../drivers/components/DriverOnlineBadge'
import { driverOnlineModeLabel } from '../../drivers/utils/driverOnlineStatus'
import type { DriverActivityItem } from '../types/dashboard.types'

interface DriverActivityProps {
  data: DriverActivityItem[]
  onlineCount: number
  onRefresh?: () => void
  isRefreshing?: boolean
}

function formatJoined(iso: string | null): string {
  if (!iso) {
    return '—'
  }
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? iso.slice(0, 10) : d.toLocaleDateString()
}

function DriverActivity({ data, onlineCount, onRefresh, isRefreshing }: DriverActivityProps) {
  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <div className="mb-4 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h2 className="text-lg font-semibold text-gray-900">Drivers online now</h2>
          <p className="mt-1 text-sm text-gray-500">
            {onlineCount === 0
              ? 'No drivers are online. Approved drivers appear here when they tap Go online in the app.'
              : `${onlineCount} driver${onlineCount === 1 ? '' : 's'} available for bookings (live from MongoDB).`}
          </p>
        </div>
        {onRefresh ? (
          <button
            type="button"
            onClick={onRefresh}
            disabled={isRefreshing}
            className="h-9 shrink-0 rounded-lg border border-gray-200 bg-white px-3 text-sm font-semibold text-gray-900 transition hover:bg-gray-50 disabled:opacity-60"
          >
            {isRefreshing ? 'Refreshing…' : 'Refresh'}
          </button>
        ) : null}
      </div>
      <div className="overflow-x-auto">
        <table className="min-w-full border-collapse">
          <thead>
            <tr>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Driver name
              </th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Phone
              </th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Online mode
              </th>
              <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                Joined
              </th>
            </tr>
          </thead>
          <tbody>
            {data.length === 0 ? (
              <tr>
                <td colSpan={4} className="px-3 py-8 text-center text-sm text-gray-500">
                  No online drivers right now.
                </td>
              </tr>
            ) : (
              data.map((driver) => (
                <tr key={driver.id} className="transition hover:bg-yellow-50">
                  <td className="border-b border-gray-100 px-3 py-3 text-sm font-medium text-gray-900">
                    {driver.name}
                  </td>
                  <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                    {driver.phone ?? '—'}
                  </td>
                  <td className="border-b border-gray-100 px-3 py-3 text-sm">
                    <DriverOnlineBadge status={driver.onlineMode} />
                    <span className="sr-only">{driverOnlineModeLabel(driver.onlineMode)}</span>
                  </td>
                  <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-500">
                    {formatJoined(driver.joinedAt)}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </section>
  )
}

export default DriverActivity
