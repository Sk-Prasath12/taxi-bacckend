export type TransactionStatus = 'Paid' | 'Pending' | 'Failed'

export interface Transaction {
  transactionId: string
  tripId: string
  customerName: string
  driverName: string
  paymentMethod: 'UPI' | 'Card' | 'Cash' | 'Wallet'
  amount: number
  status: TransactionStatus
  date: string
}

export interface DriverEarningsRow {
  driverId: string
  driverName: string
  totalTrips: number
  totalEarnings: number
  commissionDeducted: number
  netEarnings: number
}

export interface RevenueRow {
  date: string
  totalTrips: number
  driverEarnings: number
  adminCommission: number
  totalRevenue: number
}

export type PayoutStatus = 'Pending' | 'Paid'

export interface DriverPayoutRow {
  driverId: string
  driverName: string
  totalEarnings: number
  pendingPayout: number
  lastPayoutDate: string
  status: PayoutStatus
}

export interface SummaryMetrics {
  total: number
  today: number
  month: number
}
