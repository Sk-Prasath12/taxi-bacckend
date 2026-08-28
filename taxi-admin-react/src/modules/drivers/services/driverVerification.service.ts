import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import type {
  AdminDriverDocumentRow,
  DriverVerificationQueueItem,
  VerifiedDriverListItem,
} from '../types/drivers.types'
import { API_BASE_URL, ADMIN_API_BASE_URL } from '../../../config/api.config'
import {
  extractArray,
  isPendingApproval,
  mergeRowsById,
  unwrapApiPayload,
} from '../../../utils/apiResponse'

function authHeaders(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

function fail(payload: unknown, fallback: string): never {
  const message = (payload as { message?: string } | null)?.message ?? fallback
  throw new Error(message)
}

async function adminGetJson(url: string): Promise<{ ok: boolean; payload: unknown; networkError: boolean }> {
  try {
    const response = await fetch(url, { headers: authHeaders() })
    const payload = await response.json().catch(() => null)
    return { ok: response.ok, payload, networkError: false }
  } catch {
    return { ok: false, payload: null, networkError: true }
  }
}

function mapVerificationQueueRow(row: unknown): DriverVerificationQueueItem {
  const r = row as Record<string, unknown>
  const joined = r.joined_at ?? r.createdAt
  return {
    id: String(r.id ?? r._id ?? ''),
    name: String(r.name ?? 'Unknown'),
    email: String(r.email ?? ''),
    phone: r.phone != null ? String(r.phone) : null,
    driver_verification_status: String(r.driver_verification_status ?? 'PENDING'),
    documents_uploaded_count: Number(r.documents_uploaded_count ?? 0),
    joined_at:
      joined instanceof Date ? joined.toISOString() : joined != null ? String(joined) : null,
  }
}

function mapVerifiedRow(row: Record<string, unknown>): VerifiedDriverListItem {
  const joined = row.joined_at ?? row.createdAt
  return {
    id: String(row.id ?? row._id ?? ''),
    name: String(row.name ?? ''),
    email: String(row.email ?? ''),
    phone: row.phone != null ? String(row.phone) : null,
    driver_status: String(row.driver_status ?? 'OFFLINE'),
    is_driver_verified: Boolean(row.is_driver_verified),
    driver_verification_status: String(row.driver_verification_status ?? ''),
    joined_at:
      joined instanceof Date ? joined.toISOString() : joined != null ? String(joined) : null,
  }
}

async function fetchPendingFromVerificationRoutes(): Promise<{
  rows: DriverVerificationQueueItem[]
  reachedServer: boolean
}> {
  const urls = [
    `${API_BASE_URL}/admin/drivers/verification`,
    `${API_BASE_URL}/admin/drivers/pending`,
    `${ADMIN_API_BASE_URL}/admin/drivers/verification`,
    `${ADMIN_API_BASE_URL}/admin/drivers/pending`,
  ]

  for (const url of urls) {
    const { ok, payload } = await adminGetJson(url)
    if (!ok) {
      continue
    }
    const rows = extractArray(payload).map(mapVerificationQueueRow)
    return { rows, reachedServer: true }
  }

  return { rows: [], reachedServer: false }
}

async function fetchPendingFromDriversList(): Promise<{
  rows: DriverVerificationQueueItem[]
  reachedServer: boolean
}> {
  const query = 'page=1&limit=500&pending_approval=1'
  const urls = [
    `${API_BASE_URL}/admin/drivers?${query}`,
    `${ADMIN_API_BASE_URL}/admin/drivers?${query}`,
    `${API_BASE_URL}/admin/drivers?page=1&limit=500`,
    `${ADMIN_API_BASE_URL}/admin/drivers?page=1&limit=500`,
  ]

  for (const url of urls) {
    const { ok, payload } = await adminGetJson(url)
    if (!ok) {
      continue
    }
    const rows = mergeRowsById(extractArray(payload) as Array<Record<string, unknown>>)
      .filter(isPendingApproval)
      .map(mapVerificationQueueRow)
    return { rows, reachedServer: true }
  }

  return { rows: [], reachedServer: false }
}

/** Loads every new/unapproved driver from multiple API paths (works on Vercel + Docker). */
export async function fetchDriversPendingVerification(): Promise<DriverVerificationQueueItem[]> {
  const [fromVerification, fromList] = await Promise.all([
    fetchPendingFromVerificationRoutes(),
    fetchPendingFromDriversList(),
  ])

  if (!fromVerification.reachedServer && !fromList.reachedServer) {
    throw new Error(
      'Could not load pending drivers. Check admin login, VITE_API_BASE_URL on Vercel, and backend CORS_ORIGINS.',
    )
  }

  const merged = mergeRowsById([
    ...fromVerification.rows.map((row) => ({ ...row })),
    ...fromList.rows.map((row) => ({ ...row })),
  ] as Array<Record<string, unknown>>)

  return merged
    .filter(isPendingApproval)
    .map(mapVerificationQueueRow)
    .sort((a, b) => {
      const aTime = a.joined_at ? Date.parse(a.joined_at) : 0
      const bTime = b.joined_at ? Date.parse(b.joined_at) : 0
      return bTime - aTime
    })
}

export async function fetchVerifiedDrivers(): Promise<{ total: number; drivers: VerifiedDriverListItem[] }> {
  const urls = [
    `${API_BASE_URL}/admin/drivers/verified`,
    `${ADMIN_API_BASE_URL}/admin/drivers/verified`,
  ]

  for (const url of urls) {
    const { ok, payload } = await adminGetJson(url)
    if (!ok) {
      continue
    }
    const unwrapped = unwrapApiPayload(payload) as Record<string, unknown> | unknown[]
    const driversRaw = Array.isArray(unwrapped)
      ? unwrapped
      : ((unwrapped as { drivers?: unknown[] }).drivers ?? extractArray(payload))
    if (Array.isArray(driversRaw)) {
      const drivers = driversRaw.map((row) => mapVerifiedRow(row as Record<string, unknown>))
      const total =
        typeof (unwrapped as { total?: number })?.total === 'number'
          ? (unwrapped as { total: number }).total
          : drivers.length
      return { total, drivers }
    }
  }

  const fallback = await adminGetJson(`${ADMIN_API_BASE_URL}/admin/drivers?page=1&limit=500`)
  if (!fallback.ok) {
    fail(fallback.payload, 'Unable to load verified drivers.')
  }
  const rows = mergeRowsById(extractArray(fallback.payload) as Array<Record<string, unknown>>)
  const drivers = rows
    .filter(
      (row) =>
        row.is_driver_verified === true &&
        String(row.driver_verification_status ?? '') === 'APPROVED',
    )
    .map(mapVerifiedRow)
  return { total: drivers.length, drivers }
}

export async function fetchAdminDriverDocuments(driverId: string): Promise<AdminDriverDocumentRow[]> {
  const response = await fetch(`${API_BASE_URL}/admin/drivers/${driverId}/documents`, {
    headers: authHeaders(),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    fail(payload, 'Unable to load driver documents.')
  }
  const data = extractArray(payload)
  return data.map((row) => {
    const r = row as Record<string, unknown>
    return {
      id: String(r.id ?? ''),
      user_id: String(r.user_id ?? ''),
      document_type: r.document_type as AdminDriverDocumentRow['document_type'],
      document_slot: r.document_slot != null ? String(r.document_slot) : null,
      file_url: String(r.file_url ?? ''),
      file_key: String(r.file_key ?? ''),
      status: r.status as AdminDriverDocumentRow['status'],
      rejection_reason: r.rejection_reason != null ? String(r.rejection_reason) : null,
    }
  })
}

export async function downloadAdminDocumentBlob(documentId: string): Promise<{ blob: Blob; filename: string }> {
  const response = await fetch(`${API_BASE_URL}/admin/documents/${documentId}/download`, {
    headers: authHeaders(),
  })
  if (!response.ok) {
    const payload = await response.json().catch(() => null)
    fail(payload, 'Document download failed.')
  }
  const disposition = response.headers.get('Content-Disposition')
  let filename = 'document'
  const quoted = disposition?.match(/filename="([^"]+)"/)
  const unquoted = disposition?.match(/filename=([^;\s]+)/)
  if (quoted?.[1]) {
    filename = quoted[1]
  } else if (unquoted?.[1]) {
    filename = unquoted[1].replace(/"/g, '')
  }
  const blob = await response.blob()
  return { blob, filename }
}

export async function patchAdminDocumentStatus(
  documentId: string,
  input: { status: 'APPROVED' | 'REJECTED'; reason?: string },
): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/admin/documents/${documentId}/status`, {
    method: 'PATCH',
    headers: {
      ...authHeaders(),
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(
      input.status === 'REJECTED'
        ? { status: input.status, reason: input.reason ?? '' }
        : { status: input.status },
    ),
  })
  const payload = await response.json().catch(() => null)
  if (!response.ok) {
    fail(payload, 'Unable to update document status.')
  }
}

export async function finalApproveDriver(driverId: string): Promise<void> {
  const urls = [
    `${API_BASE_URL}/admin/drivers/${driverId}/approve`,
    `${ADMIN_API_BASE_URL}/admin/drivers/${driverId}/approve`,
  ]

  let lastMessage = 'Final driver approval failed.'
  for (const url of urls) {
    const response = await fetch(url, {
      method: 'PATCH',
      headers: authHeaders(),
    })
    const payload = await response.json().catch(() => null)
    if (response.ok) {
      return
    }
    lastMessage = (payload as { message?: string } | null)?.message ?? lastMessage
  }

  throw new Error(lastMessage)
}
