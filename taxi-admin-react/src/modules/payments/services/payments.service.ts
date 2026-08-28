import { ADMIN_AUTH_TOKEN_KEY } from '../../auth/services/auth.service'
import { ADMIN_API_BASE_URL } from '../../../config/api.config'
import type {
  DriverEarningsRow,
  DriverPayoutRow,
  RevenueRow,
  SummaryMetrics,
  Transaction,
  TransactionStatus,
} from '../types/payments.types'

type ApiPaymentRow = {
  payment_id?: string | null
  order_id?: string
  ride_id?: string
  customer_id?: string
  customer_name?: string | null
  driver_id?: string | null
  driver_name?: string | null
  amount?: number
  status?: string
  payment_mode?: string | null
  created_at?: string | null
}

let payoutOverrides: Record<string, Pick<DriverPayoutRow, 'status' | 'pendingPayout' | 'lastPayoutDate'>> = {}

function authHeaders(): HeadersInit {
  const token = localStorage.getItem(ADMIN_AUTH_TOKEN_KEY)
  if (!token) {
    throw new Error('Admin session not found. Please login again.')
  }
  return { Authorization: `Bearer ${token}` }
}

function formatDate(value?: string | null): string {
  if (!value) return '—'
  const d = new Date(value)
  if (Number.isNaN(d.getTime())) return value
  return d.toISOString().slice(0, 10)
}

function mapStatus(raw?: string): TransactionStatus {
  const s = (raw ?? '').toUpperCase()
  if (s === 'SUCCESS') return 'Paid'
  if (s === 'FAILED') return 'Failed'
  return 'Pending'
}

function mapMethod(raw?: string | null): Transaction['paymentMethod'] {
  const s = (raw ?? '').toUpperCase()
  if (s === 'CASH') return 'Cash'
  if (s === 'WALLET') return 'Wallet'
  if (s === 'CARD') return 'Card'
  return 'UPI'
}

function mapPayment(row: ApiPaymentRow): Transaction {
  return {
    transactionId: String(row.payment_id ?? row.order_id ?? row.ride_id ?? '—'),
    tripId: String(row.ride_id ?? '—'),
    customerName: row.customer_name ?? 'Customer',
    driverName: row.driver_name ?? 'Unassigned',
    paymentMethod: mapMethod(row.payment_mode),
    amount: Number(row.amount ?? 0),
    status: mapStatus(row.status),
    date: formatDate(row.created_at),
  }
}

async function fetchAdminPayments(): Promise<ApiPaymentRow[]> {
  const urls = [
    `${ADMIN_API_BASE_URL}/admin/payments/history?limit=200`,
    `${ADMIN_API_BASE_URL}/v1/admin/payments/history?limit=200`,
  ]
  let lastError = 'Unable to load payments.'
  for (const url of urls) {
    try {
      const response = await fetch(url, { headers: authHeaders() })
      const payload = await response.json().catch(() => null)
      if (!response.ok) {
        lastError = (payload as { message?: string } | null)?.message ?? lastError
        continue
      }
      const payments = (payload as { data?: { payments?: ApiPaymentRow[] } } | null)?.data?.payments
      if (Array.isArray(payments)) return payments
    } catch (error) {
      lastError = error instanceof Error ? error.message : lastError
    }
  }
  throw new Error(lastError)
}

export async function getTransactions(): Promise<Transaction[]> {
  const rows = await fetchAdminPayments()
  return rows.map(mapPayment)
}

export async function getDriverEarningsRows(): Promise<DriverEarningsRow[]> {
  const rows = await fetchAdminPayments()
  const byDriver = new Map<string, DriverEarningsRow>()
  for (const row of rows) {
    if (mapStatus(row.status) !== 'Paid') continue
    const driverId = row.driver_id ?? 'unassigned'
    const current = byDriver.get(driverId) ?? {
      driverId,
      driverName: row.driver_name ?? 'Unassigned',
      totalTrips: 0,
      totalEarnings: 0,
      commissionDeducted: 0,
      netEarnings: 0,
    }
    const fare = Number(row.amount ?? 0)
    const commission = Math.round(fare * 0.15)
    current.totalTrips += 1
    current.totalEarnings += fare
    current.commissionDeducted += commission
    current.netEarnings = current.totalEarnings - current.commissionDeducted
    if (row.driver_name) current.driverName = row.driver_name
    byDriver.set(driverId, current)
  }
  return [...byDriver.values()]
}

export async function getDriverEarningsSummary(): Promise<SummaryMetrics> {
  const rows = await getDriverEarningsRows()
  const today = new Date().toISOString().slice(0, 10)
  const monthPrefix = today.slice(0, 7)
  const payments = await fetchAdminPayments()
  const paid = payments.filter((row) => mapStatus(row.status) === 'Paid')
  return {
    total: rows.reduce((sum, row) => sum + row.netEarnings, 0),
    today: paid
      .filter((row) => formatDate(row.created_at) === today)
      .reduce((sum, row) => sum + Number(row.amount ?? 0), 0),
    month: paid
      .filter((row) => formatDate(row.created_at).startsWith(monthPrefix))
      .reduce((sum, row) => sum + Number(row.amount ?? 0), 0),
  }
}

export async function getRevenueRows(): Promise<RevenueRow[]> {
  const payments = await fetchAdminPayments()
  const byDate = new Map<string, RevenueRow>()
  for (const row of payments) {
    if (mapStatus(row.status) !== 'Paid') continue
    const date = formatDate(row.created_at)
    const fare = Number(row.amount ?? 0)
    const commission = Math.round(fare * 0.15)
    const current = byDate.get(date) ?? {
      date,
      totalTrips: 0,
      driverEarnings: 0,
      adminCommission: 0,
      totalRevenue: 0,
    }
    current.totalTrips += 1
    current.adminCommission += commission
    current.driverEarnings += fare - commission
    current.totalRevenue += fare
    byDate.set(date, current)
  }
  return [...byDate.values()].sort((a, b) => b.date.localeCompare(a.date))
}

export async function getRevenueSummary(): Promise<SummaryMetrics> {
  const rows = await getRevenueRows()
  const today = new Date().toISOString().slice(0, 10)
  const monthPrefix = today.slice(0, 7)
  return {
    total: rows.reduce((sum, row) => sum + row.totalRevenue, 0),
    today: rows.filter((row) => row.date === today).reduce((sum, row) => sum + row.totalRevenue, 0),
    month: rows
      .filter((row) => row.date.startsWith(monthPrefix))
      .reduce((sum, row) => sum + row.totalRevenue, 0),
  }
}

export async function getDriverPayoutRows(): Promise<DriverPayoutRow[]> {
  const earnings = await getDriverEarningsRows()
  return earnings.map((row) => {
    const override = payoutOverrides[row.driverId]
    return {
      driverId: row.driverId,
      driverName: row.driverName,
      totalEarnings: row.netEarnings,
      pendingPayout: override?.pendingPayout ?? 0,
      lastPayoutDate: override?.lastPayoutDate ?? '—',
      status: override?.status ?? 'Paid',
    }
  })
}

export async function payDriverPayout(driverId: string): Promise<void> {
  const today = new Date().toISOString().slice(0, 10)
  payoutOverrides = {
    ...payoutOverrides,
    [driverId]: { pendingPayout: 0, status: 'Paid', lastPayoutDate: today },
  }
}
