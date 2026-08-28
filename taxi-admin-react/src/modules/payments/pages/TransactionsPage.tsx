import { useEffect, useState } from 'react'
import { Link } from 'react-router-dom'
import Navbar from '../../../components/layout/Navbar'
import Sidebar from '../../../components/layout/Sidebar'
import { useAdminLayoutState } from '../../../components/layout/useAdminLayout'
import { ROUTES } from '../../../utils/constants'
import TransactionsTable from '../components/TransactionsTable'
import { getTransactions } from '../services/payments.service'
import type { Transaction } from '../types/payments.types'

function TransactionsPage() {
  const [transactions, setTransactions] = useState<Transaction[]>([])
  const layout = useAdminLayoutState()

  useEffect(() => {
    let cancelled = false
    const load = () => {
      void getTransactions()
        .then((rows) => {
          if (!cancelled) setTransactions(rows)
        })
        .catch(() => {
          if (!cancelled) setTransactions([])
        })
    }
    load()
    const timer = window.setInterval(load, 8000)
    return () => {
      cancelled = true
      window.clearInterval(timer)
    }
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
          title="Transactions"
          subtitle="Monitor payment transactions across all rides"
        />
        <main className="space-y-6 p-4 lg:p-6">
          <div className="flex flex-wrap gap-4">
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
            <Link
              to={ROUTES.ADMIN_PAYMENTS_PAYOUTS}
              className="inline-flex text-sm font-semibold text-gray-900 underline decoration-yellow-400 underline-offset-4"
            >
              Driver Payouts
            </Link>
          </div>
          <TransactionsTable transactions={transactions} />
        </main>
      </div>
    </div>
  )
}

export default TransactionsPage
