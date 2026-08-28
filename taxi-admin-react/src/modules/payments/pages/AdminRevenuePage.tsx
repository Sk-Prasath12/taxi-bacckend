import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import { RevenueTable } from '../components/DriverEarningsTable'
import RevenueStatsCards from '../components/RevenueStatsCards'
import { getRevenueRows, getRevenueSummary } from '../services/payments.service'
import type { RevenueRow, SummaryMetrics } from '../types/payments.types'

function AdminRevenuePage() {
  const [rows, setRows] = useState<RevenueRow[]>([])
  const [summary, setSummary] = useState<SummaryMetrics | null>(null)
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getRevenueRows().then(setRows)
    void getRevenueSummary().then(setSummary)
  }, [])

  return (
    <div className="flex h-screen bg-taxi-bg">
      <Sidebar
        isDrawerOpen={layout.isSidebarOpen}
        onClose={layout.closeSidebar}
        isMobile={layout.isMobile}
        isCollapsed={layout.isSidebarCollapsed}
      />
      <div className="h-screen flex-1 overflow-y-auto" style={{ marginLeft: layout.isMobile ? 0 : 256 }}>
        <Navbar
          onToggleSidebarDrawer={layout.toggleSidebar}
          onToggleSidebarCollapse={layout.toggleSidebarCollapse}
          showMenuButton={layout.isMobile}
          isSidebarCollapsed={layout.isSidebarCollapsed}
          title="Admin Revenue"
          subtitle="Platform commission and revenue analytics"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <div className="flex flex-wrap gap-4">
            <Link
              to={ROUTES.ADMIN_PAYMENTS_TRANSACTIONS}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Transactions
            </Link>
            <Link
              to={ROUTES.ADMIN_PAYMENTS_DRIVER_EARNINGS}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Driver Earnings
            </Link>
            <Link
              to={ROUTES.ADMIN_PAYMENTS_PAYOUTS}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Driver Payouts
            </Link>
          </div>
          {summary ? (
            <RevenueStatsCards
              items={[
                { label: 'Total Revenue', value: summary.total },
                { label: "Today's Revenue", value: summary.today },
                { label: 'Monthly Revenue', value: summary.month },
              ]}
            />
          ) : null}
          <RevenueTable rows={rows} />
        </main>
      </div>
    </div>
  )
}

export default AdminRevenuePage
