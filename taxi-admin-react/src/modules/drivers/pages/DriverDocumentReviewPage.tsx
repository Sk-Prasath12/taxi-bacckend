import { useCallback, useEffect, useMemo, useState } from 'react'
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import DriverDocumentCard from '../components/DriverDocumentCard'
import DriverMongoId from '../components/DriverMongoId'
import {
  fetchAdminDriverDocuments,
  fetchDriversPendingVerification,
  fetchVerifiedDrivers,
  finalApproveDriver,
  patchAdminDocumentStatus,
} from '../services/driverVerification.service'
import type { AdminDriverDocumentRow, DriverVerificationQueueItem, VerifiedDriverListItem } from '../types/drivers.types'

function DriverDocumentReviewPage() {
  const { driverId = '' } = useParams()
  const [searchParams] = useSearchParams()
  const readOnly = searchParams.get('view') === 'readonly'
  const navigate = useNavigate()
  const layout = useAdminLayoutState()
  const [queueMeta, setQueueMeta] = useState<DriverVerificationQueueItem | null>(null)
  const [verifiedMeta, setVerifiedMeta] = useState<VerifiedDriverListItem | null>(null)
  const [documents, setDocuments] = useState<AdminDriverDocumentRow[]>([])
  const [loading, setLoading] = useState(true)
  const [errorMessage, setErrorMessage] = useState('')

  const loadData = useCallback(async () => {
    if (!driverId) {
      return
    }
    setLoading(true)
    setErrorMessage('')
    try {
      const [queue, docs, verifiedResult] = await Promise.all([
        fetchDriversPendingVerification(),
        fetchAdminDriverDocuments(driverId),
        fetchVerifiedDrivers().catch(() => ({ total: 0, drivers: [] as VerifiedDriverListItem[] })),
      ])
      setQueueMeta(queue.find((d) => d.id === driverId) ?? null)
      setVerifiedMeta(verifiedResult.drivers.find((d) => d.id === driverId) ?? null)
      setDocuments(docs)
    } catch (err) {
      setErrorMessage(err instanceof Error ? err.message : 'Unable to load driver documents.')
    } finally {
      setLoading(false)
    }
  }, [driverId])

  useEffect(() => {
    void loadData()
  }, [loadData])

  const approvedCount = useMemo(
    () => documents.filter((d) => d.status === 'APPROVED').length,
    [documents],
  )

  const canFinalApprove =
    !readOnly &&
    driverId.length > 0 &&
    !(verifiedMeta?.is_driver_verified === true && verifiedMeta.driver_verification_status === 'APPROVED')

  const handleApproveDocument = async (documentId: string) => {
    await patchAdminDocumentStatus(documentId, { status: 'APPROVED' })
    await loadData()
  }

  const handleRejectDocument = async (documentId: string, reason: string) => {
    await patchAdminDocumentStatus(documentId, { status: 'REJECTED', reason })
    await loadData()
  }

  const handleFinalApprove = async () => {
    try {
      setErrorMessage('')
      await finalApproveDriver(driverId)
      navigate(ROUTES.ADMIN_DRIVER_APPROVALS, {
        state: { approvalSuccess: driverTitle },
      })
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Unable to complete final approval.'
      setErrorMessage(message)
    }
  }

  const headerMeta = queueMeta ?? verifiedMeta
  const driverTitle = headerMeta?.name ?? `Driver ${driverId}`
  const driverEmail = queueMeta?.email ?? verifiedMeta?.email
  const driverPhone = queueMeta?.phone ?? verifiedMeta?.phone

  const subtitle = readOnly
    ? 'View and download uploaded documents (read-only)'
    : 'Approve or reject each upload, then final-approve the driver'

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
          title={readOnly ? 'Verified driver — documents' : 'Driver document review'}
          subtitle={subtitle}
        />
        <main className="space-y-6 p-4 lg:p-6">
          <Link
            to={ROUTES.ADMIN_DRIVER_APPROVALS}
            className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
          >
            ← Back to approvals
          </Link>

          {!readOnly ? (
            <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-950">
              <strong>Admin steps:</strong> (1) Check each document below → Approve or Reject. (2) Click{' '}
              <strong>Approve driver ID</strong> at the bottom — only then can the driver go online in the
              APK and receive ride bookings.
            </div>
          ) : null}

          <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
            <h2 className="text-lg font-semibold text-gray-900">{driverTitle}</h2>
            <p className="mt-2 text-sm text-gray-600">
              MongoDB driver ID (use in support / API):
            </p>
            <div className="mt-1">
              <DriverMongoId id={driverId} />
            </div>
            {driverEmail ? <p className="mt-2 text-sm text-gray-600">{driverEmail}</p> : null}
            {driverPhone ? <p className="text-sm text-gray-600">{driverPhone}</p> : null}
            {verifiedMeta?.driver_status ? (
              <p className="mt-1 text-sm text-gray-500">Driver status: {verifiedMeta.driver_status}</p>
            ) : null}
            <p className="mt-2 text-sm text-gray-500">
              {approvedCount}/{documents.length} document(s) approved on file
              {readOnly ? '.' : ' — documents are optional; use Final approve to enable rides.'}
            </p>
          </section>

          {errorMessage ? (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">
              {errorMessage}
            </div>
          ) : null}

          {loading ? (
            <p className="text-sm text-gray-500">Loading documents…</p>
          ) : documents.length === 0 ? (
            <p className="text-sm text-gray-500">No documents uploaded for this driver yet.</p>
          ) : (
            <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-3">
              {documents.map((doc) => (
                <DriverDocumentCard
                  key={doc.id}
                  doc={doc}
                  readOnly={readOnly}
                  onApprove={handleApproveDocument}
                  onReject={handleRejectDocument}
                />
              ))}
            </section>
          )}

          {readOnly ? null : (
            <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
              <h3 className="text-base font-semibold text-gray-900">Final driver approval</h3>
              <p className="mt-2 text-sm text-gray-500">
                Calls <code className="rounded bg-gray-100 px-1">PATCH /admin/drivers/:id/approve</code>.
                Sets the driver to <strong>APPROVED</strong>, prepares profile for going online, and notifies
                the driver app. After this, they can receive ride bookings when online.
              </p>
              <div className="mt-4 flex flex-wrap gap-3">
                <button
                  type="button"
                  onClick={() => void handleFinalApprove()}
                  disabled={!canFinalApprove || loading}
                  className="rounded-lg bg-green-600 px-4 py-2 text-sm font-semibold text-white transition hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-50"
                >
                  Approve driver
                </button>
              </div>
            </section>
          )}
        </main>
      </div>
    </div>
  )
}

export default DriverDocumentReviewPage
