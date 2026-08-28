import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import PayoutsTable from '../components/PayoutsTable'
import { getDriverPayoutRows, payDriverPayout } from '../services/payments.service'
import type { DriverPayoutRow } from '../types/payments.types'

function DriverPayoutsPage() {
  const [rows, setRows] = useState<DriverPayoutRow[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    void getDriverPayoutRows().then(setRows)
  }, [])

  const handlePayDriver = async (driverId: string) => {
    await payDriverPayout(driverId)
    const latest = await getDriverPayoutRows()
    setRows(latest)
  }

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
          title="Driver Payouts"
          subtitle="Manage pending and completed payout cycles"
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
              to={ROUTES.ADMIN_PAYMENTS_REVENUE}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Admin Revenue
            </Link>
          </div>
          <PayoutsTable rows={rows} onPayDriver={handlePayDriver} />
        </main>
      </div>
    </div>
  )
}

export default DriverPayoutsPage
