import { useState } from 'react'
import { downloadAdminDocumentBlob } from '../services/driverVerification.service'
import type { AdminDriverDocumentRow } from '../types/drivers.types'

const TYPE_LABELS: Record<AdminDriverDocumentRow['document_type'], string> = {
  IDENTITY: 'Identity',
  VEHICLE: 'Vehicle',
  BANK: 'Bank',
  PERSONAL: 'Personal',
}

function statusLabel(status: AdminDriverDocumentRow['status']): string {
  if (status === 'APPROVED') return 'Approved'
  if (status === 'REJECTED') return 'Rejected'
  return 'Pending'
}

interface DriverDocumentCardProps {
  doc: AdminDriverDocumentRow
  /** When true, only download is shown (verified-driver archive view). */
  readOnly?: boolean
  onApprove: (documentId: string) => Promise<void>
  onReject: (documentId: string, reason: string) => Promise<void>
}

function DriverDocumentCard({ doc, readOnly = false, onApprove, onReject }: DriverDocumentCardProps) {
  const [reason, setReason] = useState('')
  const [rejectError, setRejectError] = useState('')
  const [busy, setBusy] = useState<'approve' | 'reject' | 'download' | null>(null)

  const title = doc.document_slot
    ? doc.document_slot.replace(/_/g, ' ')
    : (TYPE_LABELS[doc.document_type] ?? doc.document_type)

  const statusClass =
    doc.status === 'APPROVED'
      ? 'bg-green-100 text-green-700'
      : doc.status === 'REJECTED'
        ? 'bg-red-100 text-red-700'
        : 'bg-yellow-100 text-amber-800'

  const handleDownload = async () => {
    setBusy('download')
    try {
      const { blob, filename } = await downloadAdminDocumentBlob(doc.id)
      const url = URL.createObjectURL(blob)
      const anchor = window.document.createElement('a')
      anchor.href = url
      anchor.download = filename
      anchor.click()
      URL.revokeObjectURL(url)
    } finally {
      setBusy(null)
    }
  }

  const handleApprove = async () => {
    setBusy('approve')
    try {
      await onApprove(doc.id)
    } finally {
      setBusy(null)
    }
  }

  const handleReject = async () => {
    const trimmed = reason.trim()
    if (!trimmed) {
      setRejectError('Rejection reason is required.')
      return
    }
    setRejectError('')
    setBusy('reject')
    try {
      await onReject(doc.id, trimmed)
      setReason('')
    } finally {
      setBusy(null)
    }
  }

  return (
    <article className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h3 className="text-base font-semibold text-gray-900">{title}</h3>
        <span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusClass}`}>
          {statusLabel(doc.status)}
        </span>
      </div>
      <p className="mb-3 truncate text-xs text-gray-500" title={doc.file_key}>
        {doc.file_key}
      </p>
      <div className="flex flex-wrap gap-2">
        <button
          type="button"
          disabled={busy !== null}
          className="rounded bg-gray-800 px-3 py-1 text-sm font-semibold text-white transition hover:bg-gray-900 disabled:opacity-50"
          onClick={() => void handleDownload()}
        >
          {busy === 'download' ? 'Downloading…' : 'Download'}
        </button>
        {readOnly ? null : (
          <>
            <button
              type="button"
              disabled={busy !== null || doc.status === 'APPROVED'}
              className="rounded bg-green-500 px-3 py-1 text-sm font-semibold text-white transition hover:bg-green-600 disabled:opacity-50"
              onClick={() => void handleApprove()}
            >
              {busy === 'approve' ? 'Saving…' : 'Approve'}
            </button>
            <button
              type="button"
              disabled={busy !== null || doc.status === 'REJECTED'}
              className="rounded bg-red-500 px-3 py-1 text-sm font-semibold text-white transition hover:bg-red-600 disabled:opacity-50"
              onClick={() => void handleReject()}
            >
              {busy === 'reject' ? 'Saving…' : 'Reject'}
            </button>
          </>
        )}
      </div>
      {readOnly ? null : (
        <div className="mt-3">
          <label className="mb-1 block text-xs font-medium text-gray-600">Reason for rejection</label>
          <input
            value={reason}
            onChange={(event) => {
              setReason(event.target.value)
              if (rejectError) {
                setRejectError('')
              }
            }}
            placeholder="Required when rejecting this document"
            className="w-full rounded-lg border border-gray-200 px-3 py-2 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-yellow-200"
          />
          {rejectError ? <p className="mt-1 text-xs text-red-600">{rejectError}</p> : null}
        </div>
      )}
      {doc.status === 'REJECTED' && doc.rejection_reason ? (
        <p className="mt-2 text-xs text-red-600">Rejected: {doc.rejection_reason}</p>
      ) : null}
    </article>
  )
}

export default DriverDocumentCard
