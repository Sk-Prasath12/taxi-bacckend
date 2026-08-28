import type { Driver } from '../types/drivers.types'

interface DriverDocumentsProps {
  driver: Driver
}

function DriverDocuments({ driver }: DriverDocumentsProps) {
  const statusClass = driver.documentsStatus === 'Verified' ? 'text-green-700' : 'text-amber-700'

  return (
    <section className="rounded-xl border border-gray-200 bg-white p-5 shadow-sm">
      <h3 className="mb-4 text-lg font-semibold text-gray-900">Documents Status</h3>
      <div className="space-y-2 text-sm text-gray-500">
        <p>
          Document Verification:{' '}
          <span className={`font-semibold ${statusClass}`}>{driver.documentsStatus}</span>
        </p>
        <p>Identity Document: {driver.documentsStatus === 'Verified' ? 'Approved' : 'Pending Review'}</p>
        <p>Vehicle Registration: {driver.documentsStatus === 'Verified' ? 'Approved' : 'Pending Review'}</p>
      </div>
    </section>
  )
}

export default DriverDocuments
