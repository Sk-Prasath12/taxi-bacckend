/** Unwrap common backend response shapes from taxi-backend-main */
export function unwrapApiPayload(payload: unknown): unknown {
  if (!payload || typeof payload !== 'object') {
    return payload
  }
  const record = payload as Record<string, unknown>
  if ('data' in record && record.data !== undefined) {
    return record.data
  }
  return payload
}

export function extractArray(payload: unknown): unknown[] {
  const unwrapped = unwrapApiPayload(payload)
  if (Array.isArray(unwrapped)) {
    return unwrapped
  }
  if (unwrapped && typeof unwrapped === 'object') {
    const record = unwrapped as Record<string, unknown>
    if (Array.isArray(record.drivers)) {
      return record.drivers
    }
    if (Array.isArray(record.items)) {
      return record.items
    }
  }
  if (payload && typeof payload === 'object') {
    const record = payload as Record<string, unknown>
    if (Array.isArray(record.drivers)) {
      return record.drivers
    }
  }
  return []
}

export function isPendingApproval(row: Record<string, unknown>): boolean {
  const status = String(row.driver_verification_status ?? 'PENDING').toUpperCase()
  if (status === 'APPROVED') {
    return false
  }
  if (row.is_driver_verified === true && status === 'APPROVED') {
    return false
  }
  return true
}

export function mergeRowsById(rows: Array<Record<string, unknown>>): Array<Record<string, unknown>> {
  const byId = new Map<string, Record<string, unknown>>()
  for (const row of rows) {
    const id = String(row.id ?? row._id ?? '')
    if (!id) {
      continue
    }
    byId.set(id, { ...byId.get(id), ...row, id })
  }
  return [...byId.values()]
}
