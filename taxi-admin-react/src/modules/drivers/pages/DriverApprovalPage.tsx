import { useCallback, useEffect, useState } from 'react'
import { Link, useLocation } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import DriverMongoId from '../components/DriverMongoId'
import DriverOnlineBadge from '../components/DriverOnlineBadge'
import {
  fetchDriversPendingVerification,
  fetchVerifiedDrivers,
  finalApproveDriver,
} from '../services/driverVerification.service'
import type { DriverVerificationQueueItem, VerifiedDriverListItem } from '../types/drivers.types'
import { getApiConfigHint, isProductionMisconfiguredApi } from '../../../config/api.config'
import { ECOSYSTEM } from '../../../config/ecosystem.config'

type ApprovalsTab = 'pending' | 'verified'

function formatJoined(iso: string | null): string {
  if (!iso) {
    return '—'
  }
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString()
}

function DriverApprovalPage() {
  const location = useLocation()
  const approvalNotice = (location.state as { approvalSuccess?: string } | null)?.approvalSuccess
  const [tab, setTab] = useState<ApprovalsTab>('pending')
  const [drivers, setDrivers] = useState<DriverVerificationQueueItem[]>([])
  const [verified, setVerified] = useState<VerifiedDriverListItem[]>([])
  const [verifiedTotal, setVerifiedTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [approvingId, setApprovingId] = useState<string | null>(null)
  const [inlineSuccess, setInlineSuccess] = useState<string | null>(null)
  const layout = useAdminLayoutState()

  const loadPending = useCallback(async () => {
    const rows = await fetchDriversPendingVerification()
    setDrivers(rows)
  }, [])

  const loadVerified = useCallback(async () => {
    const result = await fetchVerifiedDrivers()
    setVerified(result.drivers)
    setVerifiedTotal(result.total)
  }, [])

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      await Promise.all([loadPending(), loadVerified()])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load.')
    } finally {
      setLoading(false)
    }
  }, [loadPending, loadVerified])

  useEffect(() => {
    void load()
  }, [load])

  useEffect(() => {
    if (tab !== 'pending') {
      return
    }
    const timer = window.setInterval(() => {
      void loadPending().catch(() => undefined)
    }, 25000)
    return () => window.clearInterval(timer)
  }, [tab, loadPending])

  useEffect(() => {
    if (tab !== 'verified') {
      return
    }
    const timer = window.setInterval(() => {
      void loadVerified().catch(() => undefined)
    }, 25000)
    return () => window.clearInterval(timer)
  }, [tab, loadVerified])

  const handleApproveDriver = async (driver: DriverVerificationQueueItem) => {
    setError(null)
    setInlineSuccess(null)
    setApprovingId(driver.id)
    try {
      await finalApproveDriver(driver.id)
      setInlineSuccess(`${driver.name} (${driver.id})`)
      await Promise.all([loadPending(), loadVerified()])
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Approval failed.')
    } finally {
      setApprovingId(null)
    }
  }

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div
        className="h-screen flex-1 overflow-y-auto"
        style={{ marginLeft: layout.isMobile ? 0 : layout.isSidebarCollapsed ? 80 : 256 }}
      >
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Driver Approvals"
          subtitle="Approve new drivers by ID and name — then they can receive rides"
        />
        <main className="space-y-6 p-4 lg:p-6">
          {approvalNotice || inlineSuccess ? (
            <div className="rounded-lg border border-green-200 bg-green-50 px-4 py-3 text-sm text-green-900">
              <strong>{approvalNotice ?? inlineSuccess}</strong> is approved. Driver can open the app,
              tap <strong>Go Online</strong>, and join the ride booking flow.
            </div>
          ) : null}

          <p className="text-sm text-gray-600">
            <strong>Workflow:</strong> Driver registers in APK → uploads documents → you review Driver ID +
            files → click <strong>Approve driver</strong> → driver can tap <strong>Go Online</strong> and
            receive bookings.
          </p>

          {isProductionMisconfiguredApi() ? (
            <div className="rounded-lg border border-amber-300 bg-amber-50 px-4 py-3 text-sm text-amber-950">
              <strong>API misconfigured for production.</strong> {getApiConfigHint()} The admin site must
              use the same backend URL as your driver APK.
            </div>
          ) : (
            <p className="text-xs text-gray-400">
              {getApiConfigHint()} · DB: {ECOSYSTEM.database.name} ({ECOSYSTEM.database.provider})
            </p>
          )}

          <div className="flex flex-wrap gap-2 rounded-xl border border-gray-200 bg-white p-2 shadow-sm">
            <button
              type="button"
              onClick={() => setTab('pending')}
              className={`rounded-lg px-4 py-2 text-sm font-semibold transition ${
                tab === 'pending'
                  ? 'bg-yellow-400 text-gray-900'
                  : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              Pending verification
              {drivers.length > 0 ? (
                <span className="ml-2 rounded-full bg-white/80 px-2 py-0.5 text-xs text-gray-800">
                  {drivers.length}
                </span>
              ) : null}
            </button>
            <button
              type="button"
              onClick={() => setTab('verified')}
              className={`rounded-lg px-4 py-2 text-sm font-semibold transition ${
                tab === 'verified'
                  ? 'bg-yellow-400 text-gray-900'
                  : 'text-gray-600 hover:bg-gray-50'
              }`}
            >
              Verified drivers
              {verifiedTotal > 0 ? (
                <span className="ml-2 rounded-full bg-white/80 px-2 py-0.5 text-xs text-gray-800">
                  {verifiedTotal}
                </span>
              ) : null}
            </button>
            <button
              type="button"
              onClick={() => void load()}
              className="ml-auto rounded-lg border border-gray-300 px-3 py-1.5 text-sm font-semibold text-gray-800 hover:bg-gray-50"
            >
              Refresh all
            </button>
          </div>

          {error ? <p className="text-sm text-red-600">{error}</p> : null}

          {tab === 'pending' ? (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              {loading ? (
                <p className="text-sm text-gray-500">Loading…</p>
              ) : drivers.length === 0 ? (
                <div className="space-y-2 text-sm text-gray-500">
                  <p>No drivers waiting for approval on this API right now.</p>
                  <p>
                    Register a new driver in the APK, then click <strong>Refresh all</strong>. If drivers
                    still do not appear, confirm Vercel <code className="rounded bg-gray-100 px-1">VITE_API_BASE_URL</code>{' '}
                    matches the APK backend URL.
                  </p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full border-collapse">
                    <thead>
                      <tr>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Driver ID
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Driver name
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Email
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Docs
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Review &amp; approve
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {drivers.map((driver) => (
                        <tr key={driver.id} className="transition hover:bg-yellow-50">
                          <td className="border-b border-gray-100 px-3 py-3 text-sm">
                            <DriverMongoId id={driver.id} compact />
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm font-semibold text-gray-900">
                            {driver.name}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            {driver.email}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            {driver.documents_uploaded_count > 0 ? (
                              <span className="rounded-full bg-blue-100 px-2 py-0.5 text-xs font-semibold text-blue-800">
                                {driver.documents_uploaded_count} uploaded
                              </span>
                            ) : (
                              <span className="text-xs text-gray-400">None yet</span>
                            )}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm">
                            <div className="flex flex-wrap items-center gap-2">
                              <Link
                                to={`/admin/drivers/approvals/${driver.id}`}
                                className="inline-flex rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-xs font-semibold text-gray-800 hover:bg-gray-50"
                              >
                                Review documents
                              </Link>
                              <button
                                type="button"
                                disabled={approvingId === driver.id}
                                onClick={() => void handleApproveDriver(driver)}
                                className="inline-flex rounded-lg bg-green-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-60"
                              >
                                {approvingId === driver.id ? 'Approving…' : 'Approve driver ID'}
                              </button>
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          ) : (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <div className="mb-4">
                <p className="text-sm text-gray-600">
                  <code className="rounded bg-gray-100 px-1">GET /admin/drivers/verified</code> — KYC
                  approved drivers. Open documents to download files when needed.
                </p>
              </div>
              {loading ? (
                <p className="text-sm text-gray-500">Loading…</p>
              ) : verified.length === 0 ? (
                <p className="text-sm text-gray-500">No verified drivers yet.</p>
              ) : (
                <div className="overflow-x-auto">
                  <table className="min-w-full border-collapse">
                    <thead>
                      <tr>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Driver ID
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Driver name
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Phone
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Email
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Online mode
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Joined
                        </th>
                        <th className="border-b border-gray-100 px-3 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">
                          Documents
                        </th>
                      </tr>
                    </thead>
                    <tbody>
                      {verified.map((row) => (
                        <tr key={row.id} className="transition hover:bg-green-50/50">
                          <td className="border-b border-gray-100 px-3 py-3 text-sm">
                            <DriverMongoId id={row.id} compact />
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-900">
                            {row.name}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            {row.phone ?? '—'}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            {row.email}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-700">
                            <DriverOnlineBadge status={row.driver_status} />
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm text-gray-600">
                            {formatJoined(row.joined_at)}
                          </td>
                          <td className="border-b border-gray-100 px-3 py-3 text-sm">
                            <Link
                              to={`/admin/drivers/approvals/${row.id}?view=readonly`}
                              className="inline-flex rounded-lg bg-green-600 px-3 py-1.5 text-sm font-semibold text-white transition hover:bg-green-700"
                            >
                              View &amp; download
                            </Link>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default DriverApprovalPage
